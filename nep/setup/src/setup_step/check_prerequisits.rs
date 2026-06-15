use crate::*;
use anyhow::anyhow;
use lazy_static::lazy_static;
use regex::Regex;
use semver::Version;
use std::collections::BTreeSet;

/// List of the names of the packages that are not under NEP control, but can
/// be installed through Neteye.
/// For each package we have a list of aliases for the same package.
/// If the user requires one but an alias is installed it's ok, and if
/// multiple aliases are installed it's ok too.
const NETEYE_MANAGEMNT_MODULES: &[&[&str]] = &[
    &["neteye"],
    &["neteye-logmanagement"],
    &["neteye-siem", "neteye-elastic-stack"],
    &["neteye-vmd"],
    &["neteye-slm"],
    &["neteye-asset"],
    &["neteye-ntopng"],
    &["neteye-cmd"],
];

fn find_module_alias(module: &str) -> Option<&'static str> {
    NETEYE_MANAGEMNT_MODULES
        .iter()
        .find(|&&m| m.contains(&module))
        .map(|x| x[0])
}

impl Context {
    pub fn check_prerequisits(&mut self, package: &Package) -> Result<()> {
        log::info!("Step 1: Checking prerequisites");

        log::info!("Step 1.1: Checking Packages prerequisites");
        for (pkg_dep_name, dep_version) in &package.packages_deps {
            match self.installed_packages.get(pkg_dep_name) {
                Some(installed_version) => {
                    if !dep_version.matches(installed_version) {
                        bail!(
                            "The package '{}' is required with version '{}' but the latest installed one is '{}'.",
                            pkg_dep_name, dep_version, installed_version,
                        );
                    }
                }
                None => {
                    let _ = self.packages.search_package_by_name(pkg_dep_name);
                    bail!(
                        "The package '{}' is required with version '{}'. Please install it.",
                        pkg_dep_name,
                        dep_version,
                    );
                }
            }
        }

        log::info!("Step 1.2: Checking Neteye prerequisites");
        if let Some(required_neteye_version) = &package.neteye_version {
            let version = std::env::var("YUM0").or_else(|_| std::env::var("DNF0"))?;
            log::trace!("Got raw neteye version: '{}'", &version);
            // they added sprint releases so instead of XX.YY now we also have
            // XX.YY-srZZ but we are interested only in the first two parts
            let version = version.split('-').next().unwrap();
            let neteye_version = Version::parse(&format!("{version}.0"))?;
            log::trace!("Got neteye version: '{}'", &neteye_version);
            if !required_neteye_version.matches(&neteye_version) {
                bail!(
                    "Needed Neteye Version '{}' but found '{}'.",
                    required_neteye_version,
                    neteye_version,
                );
            }
        }

        log::info!("Step 1.3: Checking Neteye modules prerequisites");
        if !package.neteye_modules.is_empty() {
            let mut installed_modules = BTreeSet::new();

            if self.confs.is_satellite() {
                // self.neteye_satellite_file is a json that contains stuff like:
                // {"enabled-modules": [
                //         "neteye-alyvix",
                //         "neteye-asset"
                //     ]
                // }
                // and here we should extract them to populate installed_modules
                let data = std::fs::read_to_string(&self.confs.neteye_satellite_file)
                    .with_context(|| {
                        format!(
                            "Cannot read the {} file",
                            self.confs.neteye_satellite_file.to_string_lossy()
                        )
                    })?;
                let v: serde_json::Value = serde_json::from_str(&data)
                    .with_context(|| "The neteye-cluster file is not a valid json file")?;
                let obj = v.as_object().ok_or(anyhow!(
                    "The neteye-cluster file is a valid json but it's not an object!"
                ))?;
                let modules = obj.get("enabled-modules").ok_or(anyhow!(
                    "enabled-modules not present in {}",
                    self.confs.neteye_satellite_file.to_string_lossy()
                ))?;
                let modules = modules
                    .as_array()
                    .ok_or(anyhow!("The enabled-modules field is not an array"))?;

                for module in modules {
                    let module = module.as_str().ok_or(anyhow!(
                        "The enabled-modules field {} is not a string",
                        module
                    ))?;
                    installed_modules.insert(module.to_string());
                }
                installed_modules.insert("neteye".to_string());
            } else {
                //On master:
                let result = self.exec_env.exec_master(
                    "yum",
                    &[
                        "groups",
                        "list",
                        "installed",
                        "ids",
                        "--enablerepo=neteye",
                        "neteye*",
                    ],
                    None,
                )?;

                lazy_static! {
                    static ref RE: Regex = Regex::new(r"NetEye.+\((.+)\)").unwrap();
                }

                for line in result.stdout.lines() {
                    for cap in RE.captures_iter(line) {
                        log::trace!("Found installed neteye module: '{}'", &cap[1]);
                        installed_modules.insert(cap[1].to_string());
                    }
                }
            }

            // normalize installed modules, because we have aliases
            // we map each module to the first one in the list
            let normalized_installed_modules = installed_modules
                .iter()
                .map(|x| find_module_alias(x).unwrap_or(x))
                .collect::<BTreeSet<_>>();

            for module in &package.neteye_modules {
                let normalized_module =
                    find_module_alias(module.as_str()).unwrap_or(module.as_str());
                if NETEYE_MANAGEMNT_MODULES
                    .iter()
                    .flat_map(|x| x.iter())
                    .all(|&m| m != module.as_str())
                {
                    log::warn!(
                        "Warning: Neteye module '{}' is not under nep-setup management",
                        &module
                    );
                } else {
                    if !normalized_installed_modules.contains(&normalized_module) {
                        bail!("Neteye module '{module}' is not installed");
                    }
                    log::trace!("Neteye module '{module}' is satisfied");
                }
            }
        }

        Ok(())
    }
}
