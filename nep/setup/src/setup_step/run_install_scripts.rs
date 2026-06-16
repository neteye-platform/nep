use std::collections::BTreeMap;

use crate::*;
use lazy_static::lazy_static;
use regex::Regex;

#[derive(Debug, Clone)]
struct ScriptArgs {
    pub dry_run: bool,
    pub operation: String,
    pub verbosity: String,
    pub nep_name: String,
    pub target_nep_version: String,
    pub current_nep_version: String,
    pub neteye_deployment: String,
    pub node_name: String,
    pub node_type: String,
    pub neteye_tenant_name: String,
    pub neteye_zone_name: String,
}

impl ScriptArgs {
    fn to_args_array(&self) -> Vec<&str> {
        vec![
            if self.dry_run { "1" } else { "0" },
            &self.operation,
            &self.verbosity,
            &self.nep_name,
            &self.target_nep_version,
            &self.current_nep_version,
            &self.neteye_deployment,
            &self.node_name,
            &self.node_type,
            &self.neteye_tenant_name,
            &self.neteye_zone_name,
        ]
    }
}

impl Context {
    pub fn run_preinstall_scripts(&mut self, package: &Package, cli_args: &CliArgs) -> Result<()> {
        log::info!("Step 2: Running pre-install scripts");
        self.run_install_scripts(package, "pre", cli_args)
    }

    pub fn run_postinstall_scripts(&mut self, package: &Package, cli_args: &CliArgs) -> Result<()> {
        log::info!("Step 6: Running post-install scripts");
        self.run_install_scripts(package, "post", cli_args)
    }

    fn run_install_scripts(
        &mut self,
        package: &Package,
        folder: &str,
        cli_args: &CliArgs,
    ) -> Result<()> {
        let post = self.build_path(&["setup_scripts", folder])?;
        let random_folder = self.exec_env.random_folder();
        self.exec_env
            .exec_all("mkdir", &["-p", random_folder.to_str().unwrap()], None)?;
        self.exec_env
            .sync_files_all(&post, random_folder.to_str().unwrap())?;
        for file in sorted_in_folder(&random_folder)? {
            self.exec_env
                .exec_all("chmod", &["+x", file.to_str().unwrap()], None)?;
        }

        let default_version = "0.0.0";
        let files = sorted_in_folder(&random_folder)?;
        let nodes = self.confs.get_neteye_nodes()?;

        let mut tasks = Vec::with_capacity(nodes.len());

        // Prepare the arguments for the script
        let args = ScriptArgs {
            dry_run: cli_args.dry_run,
            operation: cli_args.operation.to_string(),
            verbosity: cli_args.verbosity.to_string(),
            nep_name: package.name.clone(),
            target_nep_version: package.version.to_string(),
            current_nep_version: self
                .installed_packages
                .get(&package.name)
                .map(|v| v.to_string())
                .unwrap_or(default_version.to_string()),
            neteye_deployment: (if self.confs.is_cluster() {
                "cluster"
            } else if self.confs.is_satellite() {
                "satellite"
            } else {
                "single_node"
            })
            .to_string(),
            node_name: String::new(), // will be set in the loop
            node_type: String::new(), // will be set in the loop
            neteye_tenant_name: "master".to_string(),
            neteye_zone_name: "master".to_string(),
        };

        for (neteye_node_name, node_type) in nodes {
            let mut args = args.clone();
            args.node_name = neteye_node_name.clone();
            args.node_type = node_type.to_string();

            // satellite nodes have special handling for the zone name and tenant name
            if node_type == NodeType::Satellite {
                let (neteye_zone_name, neteye_tenant_name) = self.get_satellite_info()?;
                args.neteye_zone_name = neteye_zone_name;
                args.neteye_tenant_name = neteye_tenant_name;
            }

            tasks.push((neteye_node_name, node_type, args));
        }

        let maybe_error = std::thread::scope(|s| {
            let mut handles = BTreeMap::new();
            for (neteye_node_name, node_type, args) in tasks {
                log::info!("Starting to run scripts on {neteye_node_name:#4?}",);
                let files = &files;
                let exec_env = &self.exec_env;
                handles.insert(neteye_node_name.clone(), s.spawn(move || {
                    for file in files {
                        if node_type.is_local() {
                            log::info!("Running scripts locally with args: {args:#4?}",);
                            exec_env
                                .exec_master(file.to_str().unwrap(), &args.to_args_array(), None)
                                ?;
                        } else {
                            log::info!("Running scripts on endpoint: {neteye_node_name} with args: {args:#4?}",);
                            exec_env
                                .exec_endpoint(
                                    &neteye_node_name,
                                    file.to_str().unwrap(),
                                    &args.to_args_array(),
                                    None,
                                )?;
                        }
                    }
                    anyhow::Ok(())
                }));
            }

            let mut error = None;
            for (neteye_node_name, handle) in handles {
                match handle.join().unwrap() {
                    Ok(()) => log::info!("Finished running scripts on {neteye_node_name}",),
                    Err(e) => {
                        log::error!("Error running scripts on {neteye_node_name}: {e}");
                        error = Some(e);
                    }
                }
            }
            error
        });

        if let Some(e) = maybe_error {
            return Err(e);
        }
        Ok(())
    }

    fn get_satellite_info(&self) -> Result<(String, String)> {
        let mut neteye_zone_name = "master".to_string();
        let neteye_tenant_name;
        // first figure out the zone name
        lazy_static! {
            static ref RE: Regex = Regex::new("const ZoneName = \"(.+)\"").unwrap();
        }
        let constants =
            std::fs::read_to_string("/neteye/local/icinga2/conf/icinga2/constants.conf")?;
        log::trace!("constants.conf content: {}", &constants);
        if let Some(captures) = RE.captures(&constants) {
            neteye_zone_name = captures[1].to_string();
            log::trace!("found Zone: {}", &neteye_zone_name);
        }

        // then figure out the tenant name
        let neteye_tenant = std::fs::read_to_string("/etc/neteye-tenant");
        log::trace!("neteye-tenant content: {:?}", &neteye_tenant);
        if let Ok(tenant) = neteye_tenant {
            let tenant_out = tenant.trim().to_string();
            log::trace!("found Tenant: {}", &tenant_out);
            let values: serde_json::Value = serde_json::from_str(&tenant_out)?;
            let values = values.as_object().ok_or(anyhow::anyhow!(
                "The tenant name is not a valid JSON object"
            ))?;
            neteye_tenant_name = values
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("UNDEFINED")
                .to_string();
        } else {
            neteye_tenant_name = "UNAVAILABLE".to_string();
        }
        log::info!("Tenant: {}", &neteye_tenant_name);

        Ok((neteye_zone_name, neteye_tenant_name))
    }
}
