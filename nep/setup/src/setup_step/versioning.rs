use crate::*;

impl Context {
    pub fn versioning(&mut self, package: &Package) -> Result<()> {
        log::info!("Step 8: Versioning");
        let working_dir = self.build_path(&[])?;
        let mut target = self.confs.packages.clone();
        target.extend([&package.name, &package.version.to_string()]);
        std::fs::create_dir_all(&target)?;
        self.exec_env
            .sync_files_master(&working_dir, target.to_str().unwrap())?;
        Ok(())
    }
}
