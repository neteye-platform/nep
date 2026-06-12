// No warnings :)
#![deny(warnings)]
// the code must be safe and shouldn't ever panic!
#![deny(unsafe_code)]
#![deny(clippy::panic)]
//#![deny(clippy::panicking_unwrap)]
//#![deny(clippy::unwrap_used)]
//#![deny(clippy::expect_used)]
#![deny(unstable_features)]
// no dead code
#![deny(dead_code)]
#![deny(unconditional_recursion)]
#![deny(clippy::empty_loop)]
#![deny(unreachable_code)]
#![deny(unreachable_pub)]
#![deny(unreachable_patterns)]
#![deny(unused_macro_rules)]
#![deny(trivial_casts)]
//#![deny(unused_results)]
// the code must be documented and debuggable
#![deny(missing_debug_implementations)]
#![deny(unused_doc_comments)]
//#![deny(missing_docs)]
//#![deny(clippy::missing_docs_in_private_items)]
//#![deny(clippy::missing_doc_code_examples)]
//#![deny(clippy::missing_errors_doc)]
//#![deny(clippy::missing_panics_doc)]
//#![deny(clippy::missing_safety_doc)]
//#![deny(clippy::missing_crate_level_docs)]
mod utils;
use anyhow::{bail, Context as _, Result};
use colored::Colorize;
pub use utils::*;

mod confs;
mod context;
mod exec_env;
mod get_packages;
mod package;
mod prerequisites;
mod setup_step;
mod status;
pub use confs::*;
pub use context::*;
pub use exec_env::*;
pub use get_packages::*;
pub use package::*;
pub use prerequisites::*;
pub use setup_step::*;
pub use status::*;

pub mod build_info {
    include!(concat!(env!("OUT_DIR"), "/built.rs"));

    pub fn version_string() -> String {
        format!(
            "{}
git info: {} {} {} {}
build info: built on {} for {} with {}",
            PKG_VERSION,
            GIT_VERSION.unwrap_or(""),
            GIT_COMMIT_HASH.unwrap_or(""),
            GIT_HEAD_REF.unwrap_or(""),
            match GIT_DIRTY {
                None => "",
                Some(true) => "(dirty)",
                Some(false) => "(clean)",
            },
            BUILD_DATE,
            TARGET,
            RUSTC_VERSION
        )
    }
}

/// List of the steps needed to install a nep package.
pub const INSTALL_STEPS: [SetupStep; 9] = [
    SetupStep::CheckPrerequisites,
    SetupStep::PreInstall,
    SetupStep::SyncFiles,
    SetupStep::ImportPlugin,
    SetupStep::ImportBasketsOnce,
    SetupStep::ImportBaskets,
    SetupStep::PostInstall,
    SetupStep::ITOA,
    SetupStep::Versioning,
];

/// List of the steps needed to reinstall a nep package.
pub const REINSTALL_STEPS: [SetupStep; 7] = [
    SetupStep::CheckPrerequisites,
    SetupStep::PreInstall,
    SetupStep::SyncFiles,
    SetupStep::ImportPlugin,
    SetupStep::ImportBaskets,
    SetupStep::PostInstall,
    SetupStep::ITOA,
];

/// List of the steps needed to update a nep package.
pub const UPDATE_STEPS: [SetupStep; 8] = [
    SetupStep::CheckPrerequisites,
    SetupStep::PreInstall,
    SetupStep::SyncFiles,
    SetupStep::ImportPlugin,
    SetupStep::ImportBaskets,
    SetupStep::PostInstall,
    SetupStep::ITOA,
    SetupStep::Versioning,
];

#[derive(Debug, Clone)]
/// Information about the command line arguments that will be passed to the
/// pre and post install scripts.
pub struct CliArgs {
    /// If the operation should write the files or not.
    pub dry_run: bool,
    /// A description of the operation to perform
    pub operation: String,
    /// The verbosity level of the operation [0..3]
    pub verbosity: usize,
}

impl Context {
    /// Given the name of a package, print all the infos and constraints
    pub fn info_package(&mut self, package_name: &str) -> Result<()> {
        log::info!("Reinstalling package '{package_name}'");
        let (status, package) = self.packages.search_package_by_name(package_name)?;
        match status {
            Status::Available | Status::Installed | Status::Updatable => {
                println!("{package:#4?}");
            }
            _ => bail!("The package exists but it has status: '{:?}'", status),
        }
        Ok(())
    }

    /// Given a query search the best matching package by searching both the title
    /// and its description
    pub fn search_package(&mut self, _query: &str) -> Result<()> {
        todo!()
    }

    /// List the state and errors of all the packages, possibly filtering by status
    pub fn list_packages(&mut self, filter: &StatusFilter) -> Result<()> {
        if filter.filter(Status::Installed) && !self.packages.installed.is_empty() {
            println!();
            println!("Installed");
            println!("----------------");
            for package in self.packages.installed.values() {
                println!("{:<40} {:<10}", package.name, package.version);
            }
        }
        if filter.filter(Status::Updatable) && !self.packages.updatable.is_empty() {
            println!();
            println!("{}", "Updatable".green());
            println!("----------------");
            for package in self.packages.updatable.values() {
                let installed = self
                    .installed_packages
                    .get(&package.name)
                    .expect("how can a pacakge be updatable but not installed??");
                println!(
                    "{:<40} {:<10} => {:<10}",
                    package.name, installed, package.version
                );
            }
        }
        if filter.filter(Status::Available) && !self.packages.available.is_empty() {
            println!();
            println!("{}", "Available".yellow());
            println!("----------------");
            for package in self.packages.available.values() {
                println!("{:<40} {:<10}", package.name, package.version);
            }
        }
        if filter.filter(Status::Errored) && !self.packages.errored.is_empty() {
            println!();
            println!("{}", "Errored".red());
            println!("----------------");
            for (path, error) in self.packages.errored.iter() {
                println!("{path:<40} {error:<10}");
            }
        }

        Ok(())
    }

    pub fn install_package(
        &mut self,
        package_name: &str,
        yes: &bool,
        skip_pre: &bool,
        dry_run: bool,
        verbosity: usize,
    ) -> Result<()> {
        let cli_args = CliArgs {
            dry_run,
            operation: "install".to_string(),
            verbosity,
        };

        log::info!("Installing package '{package_name}'");

        let (status, package) = self.packages.search_package_by_name(package_name)?;
        if status != Status::Available {
            bail!("The package exists but it has status: '{:?}'", status);
        }

        // setup the working dir
        self.confs.working_dir = self.confs.stage.clone();
        self.confs.working_dir.extend(&[package_name]);

        if !yes {
            ask_for_permission()?;
        }
        check_we_are_root()?;

        for step in INSTALL_STEPS {
            if *skip_pre && step == SetupStep::CheckPrerequisites {
                continue;
            }
            self.run_install_step(&package, step, &cli_args)?;
        }

        log::info!("Installation complete!");
        Ok(())
    }

    /// IFF constraints are respected, install-again the given package
    pub fn reinstall_package(
        &mut self,
        package_name: &str,
        force: &bool,
        yes: &bool,
        skip_pre: &bool,
        dry_run: bool,
        verbosity: usize,
    ) -> Result<()> {
        let cli_args = CliArgs {
            dry_run,
            operation: "reinstall".to_string(),
            verbosity,
        };
        log::info!("Reinstalling package '{package_name}'");
        let (status, package) = self.packages.search_package_by_name(package_name)?;
        log::info!("The package exists and has status: '{:?}'", status);

        // setup the working dir
        self.confs.working_dir = self.confs.packages.clone();
        self.confs
            .working_dir
            .extend(&[package_name, &package.version.to_string()]);

        if !yes {
            ask_for_permission()?;
        }
        check_we_are_root()?;
        for step in REINSTALL_STEPS {
            if *skip_pre && step == SetupStep::CheckPrerequisites {
                continue;
            }
            if *force && step == SetupStep::ImportBaskets {
                self.run_install_step(&package, SetupStep::ImportBasketsOnce, &cli_args)?;
            }
            self.run_install_step(&package, step, &cli_args)?;
        }

        log::info!("Reinstallation complete!");
        Ok(())
    }

    pub fn update_package(
        &mut self,
        package_name: &str,
        force: &bool,
        yes: &bool,
        skip_pre: &bool,
        dry_run: bool,
        verbosity: usize,
    ) -> Result<()> {
        let cli_args = CliArgs {
            dry_run,
            operation: "update".to_string(),
            verbosity,
        };
        log::info!("Updating package '{package_name}'");

        let (status, package) = self.packages.search_package_by_name(package_name)?;
        if status != Status::Updatable {
            bail!("The package exists but it has status: '{:?}'", status);
        }

        // setup the working dir
        self.confs.working_dir = self.confs.stage.clone();
        self.confs.working_dir.extend(&[package_name]);

        if !yes {
            ask_for_permission()?;
        }
        check_we_are_root()?;
        for step in UPDATE_STEPS {
            if *skip_pre && step == SetupStep::CheckPrerequisites {
                continue;
            }
            if *force && step == SetupStep::ImportBaskets {
                self.run_install_step(&package, SetupStep::ImportBasketsOnce, &cli_args)?;
            }
            self.run_install_step(&package, step, &cli_args)?;
        }

        log::info!("Updating complete!");
        Ok(())
    }
}
