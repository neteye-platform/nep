use crate::*;
use serde_json::json;

impl Context {
    pub fn itoa(&mut self, _package: &Package) -> Result<()> {
        log::info!("Step 7: ITOA");
        let itoa = self.build_path(&["itoa"])?;

        log::debug!("Looking for ITOA dashboards in folder: {}", itoa.to_string_lossy());

        for itoa_folder in sorted_in_folder(&itoa)? {
            if !itoa_folder.is_dir() {
                log::debug!(
                    "Found file {} in ITOA folder. Skipping.",
                    itoa_folder.to_string_lossy()
                );
                continue;
            }
            log::debug!(
                "Processing ITOA dashboard folder: {}",
                itoa_folder.to_string_lossy()
            );
            for file in sorted_in_folder(&itoa_folder)? {
                log::debug!(
                    "Processing ITOA dashboard file: {}",
                    file.to_string_lossy()
                );
                if !file.extension().map_or(false, |ext| ext == "json") {
                    log::debug!(
                        "File {} is not a JSON file. Skipping.",
                        file.to_string_lossy()
                    );
                    continue;
                }
                log::info!(
                    "Parsing ITOA dashboard file: {}",
                    file.to_string_lossy()
                );
                let dash_model = match std::fs::read_to_string(&file) {
                    Ok(data) => serde_json::from_str(&data).with_context(|| {
                        format!(
                            "Error while reading itoa dashboard model file: {:?}",
                            file.to_string_lossy()
                        )
                    })?,
                    Err(err) => {
                        bail!(
                            "Cannot read itoa dashboard model: {} with error {:?}",
                            file.to_string_lossy(),
                            err
                        );
                    }
                };

                add_itoa_dashboard(dash_model)?;
            }
        }
        Ok(())
    }
}

fn add_itoa_dashboard(mut dash_model: serde_json::Value) -> Result<()> {
    if let Some(dash_model) = dash_model.as_object_mut() {
        dash_model.remove("id");
    }

    let mut dashboard = serde_json::Map::new();
    dashboard.insert("dashboard".into(), dash_model);
    dashboard.insert("message".into(), json!("Dashboard created"));
    dashboard.insert("overwrite".into(), json!(true));

    let client = reqwest::blocking::Client::new();
    let body = client
        .post("http://grafana.neteyelocal:3000/api/dashboards/db")
        .json(&dashboard)
        .header("X-WEBAUTH-USER", "root")
        .send()?;

    let status = body.status();
    let text = body.text()?;
    log::trace!("Got response: {status}");
    log::trace!("Response text: {text}");

    if status.is_success() {
        Ok(())
    } else {
        bail!(
            "Could not add itoa dashboard, got error code {} and response:\n\t{}",
            status,
            text
        )
    }
}
