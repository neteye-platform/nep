use crate::*;

impl Context {
    pub fn import_plugin_dirs(&mut self, _package: &Package) -> Result<()> {
        // step 4 plugin dirs
        log::info!("Step 4: Importing plugin dirs");
        let plugins = self.build_path(&["plugins"])?;

        if plugins.exists() {
            self.exec_env
                .exec_master("chmod", &["-R", "+x", plugins.to_str().unwrap()], None)?;
            self.exec_env.exec_master(
                "bash",
                &[
                    "-c",
                    &format!(
                        "find {} -type f -print0 | xargs -0 -n 1 -P 4 dos2unix",
                        plugins.to_str().unwrap()
                    ),
                ],
                None,
            )?;
            self.exec_env
                .sync_files_all(&plugins, "/neteye/shared/monitoring/plugins")?;
        }
        Ok(())
    }
}
