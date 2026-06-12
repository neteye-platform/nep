use crate::*;
use serde_json::Value;
use std::path::PathBuf;

impl Context {
    fn import_basket_helper(&mut self, paths: &[PathBuf]) -> Result<()> {
        for folder in paths {
            for basket in sorted_in_folder(folder)? {
                // import_basket(working_dir, neteye_hostname, b, "import")
                log::info!("Reading basket: {}", basket.to_str().unwrap());
                // read the file
                let mut basket_body: Value = match std::fs::read_to_string(&basket) {
                    Ok(data) => serde_json::from_str(&data)?,
                    Err(err) => {
                        bail!(
                            "Cannot read fs_packages_file: {} with error {:?}",
                            basket.to_string_lossy(),
                            err
                        );
                    }
                };

                // TODO!: how do I make it simpler?
                // Icinga Director bug: Sync rules that creates Data List Entries are not linked to the expected Data List
                // Workaround: Look for the Data List Id in Director Db, then replace the Data List name with the Id
                //             This is applied only to the SyncRule node of a Basket, and only if it refest to a Data List
                if let Some(sync_rule) = basket_body.as_object_mut().unwrap().get_mut("SyncRule") {
                    // Ensures we are working in the SyncRule object of a Basket
                    for value in sync_rule.as_object_mut().unwrap().values_mut() {
                        // Look for a propertyt named destination_field in each Sync Rules inside the Basket
                        if let Some(properties) =
                            value.as_object_mut().unwrap().get_mut("properties")
                        {
                            for property in properties.as_array_mut().unwrap() {
                                let property = property.as_object_mut().unwrap();

                                // check that the current property is destination_field and is equal to list_id
                                if let Some(dst_field) = property.get("destination_field") {
                                    let dst_field = dst_field.as_str().unwrap();
                                    if dst_field != "list_id" {
                                        // The current property IS destination_field but is NOT a Data List ID
                                        continue;
                                    }
                                } else {
                                    // The current property IS NOT destination_field
                                    continue;
                                }

                                // Get the Data List name
                                let datalist_name = match property.get_mut("source_expression") {
                                    Some(x) => x,
                                    None => continue,
                                };

                                // Look for the ID of the Data List in Director DB
                                let result = self.exec_env.exec_master("mysql", &[
                                    "director", "-s", "-r", "-N", "-e",
                                    &format!("SELECT id from director_datalist where list_name=\"{}\";", datalist_name.as_str().unwrap()),
                                ], None)?;

                                // Replace Data List name with Data List ID
                                *datalist_name = Value::String(result.stdout.trim().to_string());
                            }
                        }
                    }
                }

                // import in director
                if self.confs.is_cluster() {
                    self.exec_env.exec_endpoint(
                        "neteye.neteyelocal",
                        "icingacli",
                        &["director", "basket", "restore"],
                        Some(serde_json::to_string(&basket_body)?.as_bytes()),
                    )?;
                } else {
                    self.exec_env.exec_master(
                        "icingacli",
                        &["director", "basket", "restore"],
                        Some(serde_json::to_string(&basket_body)?.as_bytes()),
                    )?;
                }
            }
        }
        Ok(())
    }

    pub fn import_basket(&mut self, _package: &Package) -> Result<()> {
        // step 5 basket
        log::info!("Step 5: Importing baskets");
        let baskets = self.build_path(&["baskets", "import"])?;

        self.import_basket_helper(&[baskets])
    }

    pub fn import_basket_once(&mut self, _package: &Package) -> Result<()> {
        // step 5 basket
        log::info!("Step 5: Importing baskets once");
        let baskets_once = self.build_path(&["baskets", "import_once"])?;

        self.import_basket_helper(&[baskets_once])
    }
}
