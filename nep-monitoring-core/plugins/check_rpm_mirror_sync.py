#! /bin/python3
import gzip
import json
import logging
import os
import re
import subprocess
import tempfile

import requests
from bs4 import BeautifulSoup
from argparse import ArgumentParser

requests.packages.urllib3.disable_warnings()

# ---- TEST INFO ----
# SCOPE: This test checks if the packages on the official mirror are synchronized with the original repo
# ARGUMENTS:
#   - source_repo -> Link to the official repository (usually https://repo.wuerth-phoenix.com/rhel8/)
#   - mirror_repo -> Link to the mirror that has to be tested (e.g. https://mirror.wp.lan/pulp/content/rhel8/
# OPTIONAL EXTRA ARGUMENTS:
#   --enable_experimental -> Check if the mirror has correctly mirrored the experimental version too
#   --num_of_stable_mirrored_versions N -> Check if the mirror has cloned the last N stable versions
#       (experimental not included in the count)
#   --num_of_sr_mirrored_versions N -> Check if the mirror has cloned the last N sprint release versions
#       (experimental not included in the count)
# REQUIREMENTS: This test requires that the given mirror is already set up and working (neteye rpmmirror setup)
# EXIT CODES
#   0) SUCCESSFUL - Mirror and external repo are synchronized
#   2) FAILURE - Mirror and external repo are not synchronized


# Make a request to a repository and return the response content
def https_request_wrapper(repo_data):
    try:
        response = requests.get(repo_data, verify=True)
        if response.status_code != 200:
            logging.error(f'[-] Request failed - status code: {response.status_code} - endpoint {repo_data} ')
            exit(2)
    except requests.exceptions.SSLError:
        logging.error("[-] SSL verification failed")
        exit(2)
    except requests.exceptions.ConnectionError as e:
        logging.error(f"[-] Can't reach the endpoint {e.args[0].pool.host}")
        exit(2)
    return response.content


# Given a repository url extracts all the metadata
def get_repodata(base_url):
    # Get the repodata page
    repodata_url = base_url + '/repodata/'
    repodata_content = str(https_request_wrapper(repodata_url))

    # Extracts the url for the primary and the filelists files
    primary_occurrences = re.findall(r"[a-zA-Z0-9_.-]*primary\.xml\.gz", repodata_content)
    if len(set(primary_occurrences)) != 1:
        logging.error(f"Primary files are duplicated on {repodata_url}")
        exit(2)

    filelists_occurrences = re.findall(r"[a-zA-Z0-9_.-]*filelists\.xml\.gz", repodata_content)
    if len(set(primary_occurrences)) != 1:
        logging.error(f"Filelists are duplicated on {repodata_url}")
        exit(2)

    primary_url = repodata_url + primary_occurrences[0]
    filelists_url = repodata_url + filelists_occurrences[0]

    # Get the files
    primary_content = str(gzip.decompress(https_request_wrapper(primary_url)))
    filelists_content = str(gzip.decompress(https_request_wrapper(filelists_url)))
    return {
        "primary": BeautifulSoup(primary_content, features="xml"),
        "filelists": BeautifulSoup(filelists_content, features="xml")
    }


# Compare the primary files to check if they are synchronized
def compare_primary_repodata(repo1, repo2):
    # Look for the checksums
    pkg_ids_1 = set([pkg.text for pkg in repo1["primary"].find_all('package')])
    pkg_ids_2 = set([pkg.text for pkg in repo2["primary"].find_all('package')])

    # Compares the packages list
    pkgs_diff = pkg_ids_1.symmetric_difference(pkg_ids_2)

    if pkgs_diff:
        logging.error(f"[-] Cannot find the following packags in primary files: {str(pkgs_diff)}")
        return False
    return True


# Compare the filelists files to check if they are synchronized
def compare_filelists_repodata(repo1, repo2):
    # Look for the checksums
    pkg_ids_1 = set([pkg['pkgid'] for pkg in repo1["filelists"].find_all('package')])
    pkg_ids_2 = set([pkg['pkgid'] for pkg in repo2["filelists"].find_all('package')])

    # Compares the filelists files
    pkgs_diff = pkg_ids_1.symmetric_difference(pkg_ids_2)

    if pkgs_diff:
        logging.error(f"[-] Cannot find the following packags in primary files: {str(pkgs_diff)}")
        return False
    return True


# Get the list of packages available in a repository
def get_repository_list(base_url):
    base_url_content = str(https_request_wrapper(base_url))
    repo_list = re.findall(r"(?<=href=\")[a-zA-Z0-9_.-]*", base_url_content)
    repo_list.remove('..')
    repo_list.remove('listing')

    return repo_list


# Reads the active mirror configuration file and returns the specified url
def get_mirror_url(config_file_path='/etc/neteye-rpm-mirror'):
    if not os.path.isfile(config_file_path):
        logging.error("[-] Missing mirror configuration file")
        exit(2)

    with open(config_file_path) as f:
        json_data = json.loads(f.read())
        if "rpm_mirror_host" not in json_data:
            logging.error("[-] Mirror configuration file is missing 'rpm_mirror_host' parameter")
            exit(2)
        url = f'https://{json_data["rpm_mirror_host"]}:8443/pulp/content/rhel8/'
    return url


def get_last_n_versions_by_type(
        n_versions: int,
        use_sr_type: bool, *,
        url: str = 'https://api.neteye.cloud/v2/config/versions.json',
        enable_experimental_versions: bool = False):
    '''
    Return the last N stable versions from the given url and all the experimental versions if enabled
    Example assuming that n_versions = 2 and enable_experimental_versions = True:
        (4.41 -> unreleased, 4.40 -> unreleased, 4.39 -> released, 4.38 -> released, 4.37 -> released, ...)
    will return: [4.41, 4.40, 4.39, 4.38]

    :param n_versions: number of released stable versions to return
    :param use_sr_type: Whether to return the sprint release version or stable ones
    :param url: Url of the api to get the versions list from
    :param enable_experimental_versions: If True, the experimental versions will be included in the list
    :return: List of the last N stable versions and the experimental versions if enabled
    '''
    # Complete list of all the versions
    versions_list = json.loads(https_request_wrapper(url))

    # Filter the list of versions by the release type
    type_filtered_versions = list(filter(lambda version: version['sprint_release'] == use_sr_type, versions_list))
    # Extract the released versions
    exposed_versions = list(filter(lambda version: version['released'], type_filtered_versions))
    # Get the last N
    sliced_exposed_versions = exposed_versions[:n_versions]

    # Add the experimental versions if enabled
    if enable_experimental_versions:
        # Extract the unreleased versions of the same kind
        unreleased_versions = list(filter(lambda version: not version['released'], type_filtered_versions))
        # Add the unreleased versions to the list (in front because they are supposed to be the most recent)
        sliced_exposed_versions = unreleased_versions + sliced_exposed_versions

    # Return the list of versions ignoring redundant fields
    return [r['version'] for r in sliced_exposed_versions]


if __name__ == '__main__':
    logging.basicConfig(format='%(message)s', level=logging.INFO)

    parser = ArgumentParser()
    parser.add_argument("source_repo")

    parser.add_argument("mirror_repo")

    # Number of stable versions that we expect the mirror has cloned (6 by default)
    parser.add_argument("--num_of_stable_mirrored_versions", dest="num_of_stable_mirrored_versions", default=6,
                        type=int)

    # Number of sprint release versions that we expect the mirror has cloned (6 by default)
    parser.add_argument("--num_of_sr_mirrored_versions", dest="num_of_sr_mirrored_versions", default=0, type=int)

    # Include experimental version in the mirror check
    parser.add_argument("--enable_experimental", dest="enable_experimental", action="store_true", default=False)

    args = parser.parse_args()

    EXTERNAL_REPO_URL = args.source_repo
    MIRROR_REPO_URL = args.mirror_repo
    NUM_STABLE_MIRRORED_VERSIONS = args.num_of_stable_mirrored_versions
    NUM_SR_MIRRORED_VERSIONS = args.num_of_sr_mirrored_versions
    ENABLE_EXPERIMENTAL = args.enable_experimental
    NETEYE_VERSION_REGEX = re.compile(r'\d\.\d{2}(?:-sr\d)?')

    # Get the list of the last N sprint release versions and the experimental ones if enabled
    exposed_repos = get_last_n_versions_by_type(NUM_SR_MIRRORED_VERSIONS, use_sr_type=True,
                                                enable_experimental_versions=ENABLE_EXPERIMENTAL)

    # Add the last N stable versions to the list (experimental conditionally included)
    exposed_repos.extend(get_last_n_versions_by_type(NUM_STABLE_MIRRORED_VERSIONS, use_sr_type=False,
                                                     enable_experimental_versions=ENABLE_EXPERIMENTAL))

    repo_list = get_repository_list(EXTERNAL_REPO_URL)
    for repo in repo_list:
        neteye_repo_version = re.findall(NETEYE_VERSION_REGEX, repo)
        if len(neteye_repo_version) != 1:
            logging.error(f"[-] Cannot find the neteye version in the repository name: {repo}")
            exit(2)

        # Skips if the neteye version it's not expected to be on the mirror
        if neteye_repo_version[0] not in exposed_repos:
            continue

        # Compare the metadata of the two repositories
        r1 = get_repodata(f'{EXTERNAL_REPO_URL}{repo}/')
        r2 = get_repodata(f'{MIRROR_REPO_URL}{repo}/')
        if not (compare_primary_repodata(r1, r2) or compare_filelists_repodata(r1, r2)):
            logging.error(f"This error occurred while comparing the following repos: {repo}")
            exit(2)
        logging.info(f"Metadata comparison test passed - {repo}")

    logging.info('[+] All test passed')
exit(0)
