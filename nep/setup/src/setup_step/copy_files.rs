use crate::*;
use anyhow::{bail, Result};
use lazy_static::lazy_static;
use regex::Regex;
use std::{
    collections::{BTreeMap, HashMap},
    path::PathBuf,
    process::Command,
};

/// structs used to parse the output of `pcs resource config` in json format
mod pcs {
    use serde::{Deserialize, Serialize};
    #[derive(Serialize, Deserialize)]
    pub(super) struct Resources {
        pub primitives: Vec<Primitive>,
    }

    #[derive(Serialize, Deserialize)]
    pub(super) struct Primitive {
        pub id: String,
        pub instance_attributes: Vec<Attributes>,
    }

    #[derive(Serialize, Deserialize)]
    pub(super) struct Attributes {
        pub nvpairs: Vec<Nvpair>,
    }

    #[derive(Serialize, Deserialize)]
    pub(super) struct Nvpair {
        pub id: String,
        pub name: String,
        pub value: String,
    }
}

/// Returns the map of each subfolder of `/neteye/shared/` on which node is mounted.
/// If `/neteye/shared/nedi/` is mounted on `/neteye4n1.neteyelocal`, the returned
/// map will contain: `nedi` -> `neteye4n1.neteyelocal`.
/// This should be called only on clusters.
fn load_files_map() -> Result<BTreeMap<PathBuf, String>> {
    let mut resources_map = BTreeMap::new();

    let stdout = Command::new("pcs").arg("resource").output()?.stdout;

    lazy_static! {
        static ref RE: Regex =
            Regex::new(r"\*\s*(\S+)\s+\(ocf::\S+:Filesystem\):\s*(\S+)\s*(\S+)").unwrap();
    }

    for line in std::str::from_utf8(&stdout)?.lines() {
        for cap in RE.captures_iter(line) {
            log::trace!("Parsing pcs line '{}'", &cap[0]);
            let resource_id = &cap[1];
            let status = &cap[2];
            let node = &cap[3];
            if status != "Started" {
                bail!(
                    "The service `{}` hosted on `{}` is not started and has status `{}`",
                    resource_id,
                    node,
                    status
                );
            }
            let prev = resources_map.insert(resource_id.to_string(), node.to_string());
            log::trace!("Found `{resource_id}` is hosted on `{node}`");
            debug_assert!(
                prev.is_none(),
                "The same pcs id is specified multiple times: '{}'",
                prev.unwrap()
            );
        }
    }

    let mut res = BTreeMap::new();
    let stdout = Command::new("pcs")
        .arg("resource")
        .arg("config")
        .arg("--output-format=json")
        .output()?
        .stdout;
    let parsed: pcs::Resources = serde_json::from_slice(&stdout)?;

    for primitive in parsed.primitives {
        let id = primitive.id;
        for attribute in primitive.instance_attributes {
            for nvpair in attribute.nvpairs {
                if nvpair.name == "directory" {
                    let path = nvpair.value.trim_end_matches('/').trim();
                    if !path.starts_with("/neteye/shared/") {
                        bail!(
                            "Found non standard path: '{}' for service id '{}'",
                            path,
                            id
                        );
                    }
                    let path = path.trim_start_matches("/neteye/shared/");
                    log::trace!("Found path `{path}` for id `{id}`");
                    let node = resources_map.get(id.as_str()).ok_or(anyhow::format_err!(
                        "Found path `{path}` with unknown ID `{id}`",
                    ))?;
                    log::trace!("Resolved `{path}` on `{node}`");
                    let prev = res.insert(PathBuf::from(path), node.to_string());
                    debug_assert!(
                        prev.is_none(),
                        "The same pcs id is specified multiple times: '{}'",
                        prev.unwrap()
                    );
                }
            }
        }
    }

    Ok(res)
}

impl Context {
    pub fn copy_files(&mut self, _package: &Package) -> Result<()> {
        // step 3, copy all files
        log::info!("Step 3: Copying files");

        let neteye_local_root = self.build_path(&["custom_files", "neteye_local_root"])?;
        let system_root = self.build_path(&["custom_files", "system_root"])?;

        // copy files rsync -a --exclude='*.md' {source} {target}
        log::info!("Step 3.1: Copying files: neteye_local_root");
        self.exec_env
            .sync_files_all(&neteye_local_root, "/neteye/local/")?;
        log::info!("Step 3.2: Copying files: system_root");
        self.exec_env.sync_files_all(&system_root, "/")?;

        let mut mount_map = BTreeMap::new();
        if self.confs.is_cluster() {
            mount_map = load_files_map()?;
        }
        let shared = self.build_path(&["custom_files", "neteye_shared_root"])?;
        let target = PathBuf::from("/neteye/shared");

        log::info!("Step 3.3: Copying files: fs_packages");
        let fs_packages = self
            .fs_packages
            .iter()
            .map(|x| (x.name.as_str(), x))
            .collect::<HashMap<_, _>>();

        for subfolder in sorted_in_folder(&shared)? {
            let subfolder = subfolder.canonicalize()?;
            let folder_name = PathBuf::from(subfolder.file_name().unwrap());

            if let Some(fs_package) = fs_packages.get(folder_name.to_str().unwrap()) {
                log::info!(
                    "Changing permissions files for fs_package {}",
                    fs_package.name
                );
                for sub in sorted_in_folder(&subfolder)? {
                    // 20230909 WP-PERC: Don't remember why owner of a directory named conf must be root:root.
                    //                   Removing this code.

                    // let ownership = if sub.file_name().unwrap().to_string_lossy() == "conf" {
                    //     "root:root".into()
                    // } else {
                    //     format!("{}:{}", fs_package.user, fs_package.group)
                    // };
                    let ownership = format!("{}:{}", fs_package.user, fs_package.group);

                    self.exec_env.exec_master(
                        "chown",
                        &["-R", &ownership, sub.to_str().unwrap()],
                        None,
                    )?;
                }
            }

            if self.confs.is_cluster() {
                let dst_endpoint = mount_map.get(&folder_name);
                if dst_endpoint.is_none() {
                    bail!(
                        "Could not find a node that mounted folder `/neteye/shared/{}`",
                        folder_name.to_string_lossy()
                    );
                }
                self.exec_env.sync_files_endpoint(
                    dst_endpoint.unwrap(),
                    &shared.join(&folder_name),
                    &target.join(&folder_name).to_string_lossy(),
                )?;
            } else {
                self.exec_env.sync_files_master(
                    &shared.join(&folder_name),
                    &target.join(&folder_name).to_string_lossy(),
                )?;
            }
        }
        Ok(())
    }
}
