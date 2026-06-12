use super::*;
use anyhow::{bail, Result};
use std::collections::BTreeMap;
use std::path::Path;

#[must_use]
pub fn get_packages_in_path<P: AsRef<Path>>(root_dir: &P) -> Vec<(String, Result<Package>)> {
    // build "root_dir/**/prerequisites.ini"
    let stage_pattern = root_dir
        .as_ref()
        .join("**")
        .join("prerequisites.ini")
        .to_path_buf();

    // use glob to expand this path
    glob::glob(stage_pattern.to_str().unwrap())
        .unwrap()
        // a nep repo shouldn't have wierd chars in the paths
        .map(|path| path.unwrap())
        .map(|path| {
            // get the folder path, this will never panic because the glob ensures that there is at least a folder
            let package_folder = path
                .parent()
                .unwrap()
                // the path can't be empty, this panics only if the package is in / but that would be a really bad idea
                .file_name()
                .unwrap()
                // convert it to a &str, nep sound't have wierd chars in the package names
                .to_str()
                .unwrap()
                // convert it to an owned String
                .to_string();

            // try to parse the prerequisites of this package
            let package = Prerequisites::open(&path).map(Package::from);

            (package_folder, package)
        })
        .collect::<Vec<_>>()
}

#[derive(Debug, Default)]
pub struct Packages {
    pub installed: BTreeMap<String, Package>,
    pub updatable: BTreeMap<String, Package>,
    pub available: BTreeMap<String, Package>,

    pub errored: BTreeMap<String, anyhow::Error>,
}

impl Packages {
    pub fn search_package_by_name(&self, package_name: &str) -> Result<(Status, Package)> {
        if let Some(pkg) = self.installed.get(package_name) {
            return Ok((Status::Installed, pkg.clone()));
        }
        if let Some(pkg) = self.updatable.get(package_name) {
            return Ok((Status::Updatable, pkg.clone()));
        }
        if let Some(pkg) = self.available.get(package_name) {
            return Ok((Status::Available, pkg.clone()));
        }

        let mut names = vec![];

        // extract available packages
        self.available
            .iter()
            .map(|(name, package)| (name, Status::Available, package.version.to_string()))
            .for_each(|d| names.push(d));

        // extract installed packages
        self.installed
            .iter()
            .map(|(name, package)| (name, Status::Installed, package.version.to_string()))
            .for_each(|d| names.push(d));

        // extract updatable packages
        self.updatable
            .iter()
            .map(|(name, package)| (name, Status::Updatable, package.version.to_string()))
            .for_each(|d| names.push(d));

        // extract updatable errored packages
        //self.errored.iter().map(|(name, error)| {
        //    (name, Status::UpdatableErrored, error.to_string())
        //}).for_each(|d| names.push(d));

        // sort by distance
        names.sort_by_cached_key(|(name, _status, _version_or_error)| {
            crate::utils::SortableFloat(-strsim::jaro_winkler(name, package_name))
        });

        let mut res = String::new();
        for (name, status, version_or_error) in names.iter().take(10) {
            res.push_str(&format!("\t{name:<30} - {status:?} - {version_or_error}\n"));
        }

        bail!(
            "The package {} does not exists.\nThe closest ones are:\n{}",
            package_name,
            res
        );
    }
}
