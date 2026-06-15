use crate::*;
use semver::Version;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

/// The whole execution context.
/// This structure completely summarize where we should execute, how, what and
/// the status of the installed and installable packages
#[derive(Debug)]
pub struct Context {
    /// paths
    pub confs: Confs,
    pub packages: Packages,
    pub fs_packages: Vec<FsPackage>,
    /// The environment, this includes all the detected siblings nodes
    pub exec_env: ExecEnv,
    pub installed_packages: BTreeMap<String, Version>,
}

#[derive(Debug, Serialize, Deserialize)]
/// The content of an fs_package (basket), currently it's only used to set chown
/// of the files we import.
/// TODO!: should we rename it to basket?
pub struct FsPackage {
    /// Name of the basket
    /// Example: "mysql"
    pub name: String,
    /// The user to assign to all files in the basket
    /// Example: "mysql"
    pub user: String,
    /// The group to assign to all files in the basket
    /// Example: "root"
    pub group: String,
}

impl Context {
    pub fn new(confs: Confs) -> Result<Self> {
        if confs.is_cluster() && !confs.is_nep_master()? {
            log::error!("This is not the master node for nep-setup service\nPlease run this command in the master node.");
            std::process::exit(1);
        }

        let fs_packages = match std::fs::read_to_string(&confs.fs_packages_file) {
            Ok(data) => serde_json::from_str(&data).with_context(|| {
                format!(
                    "Error while reading fs_packages file: {:?}",
                    confs.fs_packages_file.to_string_lossy()
                )
            })?,
            Err(err) => {
                bail!(
                    "Cannot read fs_packages_file: {} with error {:?}",
                    confs.fs_packages_file.to_string_lossy(),
                    err
                );
            }
        };

        let mut installed_packages = BTreeMap::new();
        for package_folder in sorted_in_folder(&confs.packages)? {
            log::trace!(
                "Exploring packages folder: {}",
                package_folder.to_str().unwrap()
            );
            let pkg_name = package_folder.file_name().unwrap().to_str().unwrap();
            let mut max_version = None;
            for path in sorted_in_folder(&package_folder)? {
                let version = Version::parse(path.file_name().unwrap().to_str().unwrap()).unwrap();
                log::trace!("{pkg_name} : {version}");

                match max_version {
                    Some(max_version_inner) => {
                        max_version = Some(version.max(max_version_inner));
                    }
                    None => {
                        max_version = Some(version);
                    }
                }
            }

            if let Some(max_version) = max_version {
                log::debug!("Max installed version for {pkg_name} is {max_version}");
                installed_packages.insert(pkg_name.to_string(), max_version);
            }
        }

        let packages = confs.get_packages(&installed_packages)?;

        Ok(Context {
            confs: confs.clone(),
            packages,
            fs_packages,
            exec_env: ExecEnv::new(&confs)?,
            installed_packages,
        })
    }

    pub fn build_path(&self, components: &[&str]) -> Result<PathBuf> {
        let mut working_dir = self.confs.working_dir.clone();
        working_dir.extend(components);
        Ok(working_dir)
    }

    pub fn run_install_step(
        &mut self,
        package: &Package,
        step: SetupStep,
        cli_args: &CliArgs,
    ) -> Result<()> {
        // on satellites we should not import baskets or ITOA
        if self.confs.is_satellite() {
            match step {
                SetupStep::ImportBaskets | SetupStep::ImportBasketsOnce | SetupStep::ITOA => {
                    return Ok(())
                }
                _ => {}
            }
        }

        match step {
            SetupStep::CheckPrerequisites => self.check_prerequisits(package),
            SetupStep::PreInstall => self.run_preinstall_scripts(package, cli_args),
            SetupStep::SyncFiles => self.copy_files(package),
            SetupStep::ImportBaskets => self.import_basket(package),
            SetupStep::ImportBasketsOnce => self.import_basket_once(package),
            SetupStep::ITOA => self.itoa(package),

            SetupStep::ImportPlugin => self.import_plugin_dirs(package),
            SetupStep::PostInstall => self.run_postinstall_scripts(package, cli_args),
            SetupStep::Versioning => self.versioning(package),
        }
    }
}
