mod check_prerequisits;
mod copy_files;
mod import_basket;
mod import_plugin_dirs;
mod itoa;
mod run_install_scripts;
mod versioning;

#[non_exhaustive]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
/// The installation process follows strictly these phases inorder
pub enum SetupStep {
    /// Check that all the constraints are respected
    CheckPrerequisites,

    /// Run the pre-installation bash scripts in alphabetical order
    PreInstall,

    /// Copy the files of the new package on all the cluster nodes
    SyncFiles,

    /// Copy the "plugin" files to their folder on the master node
    ImportPlugin,

    /// Copy the "plugin" files to their folder on the master node, only the
    /// import folder, not the import_once
    ImportBaskets,
    /// Copy the "plugin" files to their folder on the master node, only the
    /// import_once folder, not the import
    ImportBasketsOnce,

    /// Run the post-installation bash scripts in alphabetical order
    PostInstall,

    /// Run grafana integration
    ITOA,

    /// Define a rollback backup copy and unistall
    /// ```
    /// dnf history info 4
    /// dnf history undo
    /// dnf history rollback
    /// ```
    //Rollback,

    /// Copy the installer folder to our versioning folder so that
    /// it could be re-installed later if needed
    Versioning,
}

/*
impl TryFrom<&str> for SetupStep {
    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {

        }
    }
} */
