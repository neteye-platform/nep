use anyhow::{Context as _, Result};
use clap::{value_parser, Arg, ArgAction, Command};
use libnep::*;
use log::debug;
use std::{path::PathBuf, str::FromStr};

fn main() -> Result<()> {
    let confs = Confs::default();
    let command = Command::new(env!("CARGO_PKG_NAME"))
        .about(env!("CARGO_PKG_DESCRIPTION"))
        .version(libnep::build_info::version_string().as_str())
        .author(env!("CARGO_PKG_AUTHORS"))
        .subcommand_required(true)
        .arg_required_else_help(true)
        .propagate_version(true)
        .arg(
            Arg::new("stage")
                .default_value(confs.stage.to_str().unwrap())
                .global(true)
                .help("The folder with the **new** packages")
        )
        .arg(
            Arg::new("packages")
                .default_value(confs.packages.to_str().unwrap())
                .global(true)
                .help("The versioning history of the installed packages")
        )
        .arg(
            Arg::new("neteye_cluster_file")
                .default_value(confs.neteye_cluster_file.to_str().unwrap())
                .global(true)
                .help("The path where neteye writes the other nodes informations on a cluster")
        )
        .arg(
            Arg::new("fs_packages_file")
                .default_value(confs.fs_packages_file.to_str().unwrap())
                .global(true)
                .help("The path to a json describing the baskets")
        )
        //.arg(
        //    Arg::new("no-graceful")
        //        .short('n')
        //        .long("no-graceful")
        //        .action(ArgAction::SetTrue)
        //        .global(true)
        //        .help("If this flag is enabled, nep will not die gracefully, and it will not try to rollback.")
        //)
        .arg(
            Arg::new("dry_run")
                .long("dry-run")
                .action(ArgAction::SetTrue)
                .global(true)
                .help("WORK IN PROGRESS, NOT READY. If this flag is enabled, nep will not execute any command, it will just print what it would do.")
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .action(ArgAction::Count)
                .global(true)
                .help("How much verbose it will be. `-v` for info, `-vv` for debug, `-vvv` for trace. If not passed it defaults to the enviromment variable `NEP_LOG`")
        )
        .subcommand(
            Command::new("list")
                .about("List the packages")
                .arg(
                    Arg::new("filter")
                        .ignore_case(true)
                        .default_value("all")
                        .help("Filter the packagers to list by status")
                        .value_parser(value_parser!(StatusFilter))
                )
        )
        .subcommand(
            Command::new("info")
                .about("Get informations about a package")
                .arg(
                    Arg::new("package_name")
                        .required(true)
                        .help("Get infos about a package")
                )
        )
        //.subcommand(
        //    Command::new("search")
        //        .about("Search a packages between the availables")
        //        .arg(
        //            Arg::new("query")
        //                .required(true)
        //                .help("The textual query which will be searched both in the packages names and descriptions")
        //        )
        //)
        .subcommand(
            Command::new("install")
                .about("Install a nep")
                .arg(
                    Arg::new("package_name")
                        .required(true)
                        .help("The package to install")
                )
                .arg(
                    Arg::new("force")
                        .short('f')
                        .long("force")
                        .action(ArgAction::SetTrue)
                        .help("Skip the prerequisites check")
                )
                .arg(
                    Arg::new("yes")
                        .short('y')
                        .long("yes")
                        .action(ArgAction::SetTrue)
                        .help("Don't ask if the user is sure before running")
                )
                .arg(
                    Arg::new("skip_pre")
                        .short('s')
                        .long("skip-pre")
                        .action(ArgAction::SetTrue)
                        .help("Don't check the prerequisites and just install the package")
                )
        )
        .subcommand(
            Command::new("reinstall")
                .about("Reinstall a Nep")
                .arg(
                    Arg::new("package_name")
                        .required(true)
                        .help("The package to reinstall")
                )
                .arg(
                    Arg::new("force")
                        .short('f')
                        .long("force")
                        .action(ArgAction::SetTrue)
                        .help("Skip the prerequisites check")
                )
                .arg(
                    Arg::new("yes")
                        .short('y')
                        .long("yes")
                        .action(ArgAction::SetTrue)
                        .help("Don't ask if the user is sure before running")
                )
                .arg(
                    Arg::new("skip_pre")
                        .short('s')
                        .long("skip-pre")
                        .action(ArgAction::SetTrue)
                        .help("Don't check the prerequisites and just reinstall the package")
                )
        )
        .subcommand(
            Command::new("update")
                .about("Update a nep")
                .arg(
                    Arg::new("package_name")
                        .required(true)
                        .help("The package to update")
                )
                .arg(
                    Arg::new("force")
                        .short('f')
                        .long("force")
                        .action(ArgAction::SetTrue)
                        .help("Skip the prerequisites check")
                )
                .arg(
                    Arg::new("yes")
                        .short('y')
                        .long("yes")
                        .action(ArgAction::SetTrue)
                        .help("Don't ask if the user is sure before running")
                )
                .arg(
                    Arg::new("skip_pre")
                        .short('s')
                        .long("skip-pre")
                        .action(ArgAction::SetTrue)
                        .help("Don't check the prerequisites and just update the package")
                )
        )
        .get_matches();

    // setup the log level depending on the verbosity flag given
    let dry_run = *command.get_one::<bool>("dry_run").unwrap();
    let verbosity = command.get_count("verbose") as usize;
    match verbosity {
        0 => {
            // not passed, default to the env var
            pretty_env_logger::init_custom_env("NEP_LOG");
        }
        1 => {
            let mut builder = pretty_env_logger::formatted_builder();
            builder.parse_filters("info");
            builder.init()
        }
        2 => {
            let mut builder = pretty_env_logger::formatted_builder();
            builder.parse_filters("debug");
            builder.init()
        }
        3.. => {
            let mut builder = pretty_env_logger::formatted_builder();
            builder.parse_filters("trace");
            builder.init()
        }
    }
    debug!("Parsing configurations");

    // extract the configuration so that it can be validated once and printed
    let stage = PathBuf::from_str(command.get_one::<String>("stage").unwrap()).unwrap();
    let packages = PathBuf::from_str(command.get_one::<String>("packages").unwrap()).unwrap();
    let neteye_cluster_file =
        PathBuf::from_str(command.get_one::<String>("neteye_cluster_file").unwrap()).unwrap();
    let fs_packages_file =
        PathBuf::from_str(command.get_one::<String>("fs_packages_file").unwrap()).unwrap();
    let confs = Confs::new(stage, packages, neteye_cluster_file, fs_packages_file)?;

    debug!("Starting with confs :{confs:#4?}");

    // TODO!: handle no-graceful
    //if !command.get_one::<bool>("no-graceful").unwrap() {
    //    let handler_confs = confs.clone();
    //    ctrlc::set_handler(move || {
    //        handler_confs.cleanup().unwrap();
    //    })
    //    .expect("Error setting Ctrl-C handler");
    //}

    if confs.is_satellite() {
        log::info!("Starting on a satellite node");
    } else if confs.is_cluster() {
        if confs.is_nep_master()? {
            log::info!("Starting on a master node");
        } else {
            log::info!("Starting on a cluster node");
        }
    } else {
        log::info!("Starting on a standalone node");
    }

    let mut context = Context::new(confs)?;
    match command.subcommand().unwrap() {
        ("info", sub_matches) => {
            let package_name = sub_matches
                .get_one::<String>("package_name")
                .expect("required");
            context
                .info_package(package_name)
                .with_context(|| format!("Failed retrieving infos for package {package_name:?}"))
        }
        //("search", sub_matches) => {
        //    let query = sub_matches.get_one::<String>("query").expect("required");
        //    search_package(&confs,query)
        //        .with_context(|| format!("Failed searching package with query {:?}", query))
        //},
        ("list", sub_matches) => {
            let filter = sub_matches
                .get_one::<StatusFilter>("filter")
                .expect("required");
            context
                .list_packages(filter)
                .with_context(|| "Failed listing packages")
        }
        ("install", sub_matches) => {
            let package_name = sub_matches
                .get_one::<String>("package_name")
                .expect("required");
            //let force = sub_matches.get_one::<bool>("force").expect("required");
            let yes = sub_matches.get_one::<bool>("yes").expect("required");
            let skip_pre = sub_matches.get_one::<bool>("skip_pre").expect("required");
            context
                .install_package(package_name, yes, skip_pre, dry_run, verbosity)
                .with_context(|| format!("Failed installing package {package_name:?}"))
        }
        ("reinstall", sub_matches) => {
            let package_name = sub_matches
                .get_one::<String>("package_name")
                .expect("required");
            let force = sub_matches.get_one::<bool>("force").expect("required");
            let yes = sub_matches.get_one::<bool>("yes").expect("required");
            let skip_pre = sub_matches.get_one::<bool>("skip_pre").expect("required");
            context
                .reinstall_package(package_name, force, yes, skip_pre, dry_run, verbosity)
                .with_context(|| format!("Failed reinstalling package {package_name:?}"))
        }
        ("update", sub_matches) => {
            let package_name = sub_matches
                .get_one::<String>("package_name")
                .expect("required");
            let force = sub_matches.get_one::<bool>("force").expect("required");
            let yes = sub_matches.get_one::<bool>("yes").expect("required");
            let skip_pre = sub_matches.get_one::<bool>("skip_pre").expect("required");
            context
                .update_package(package_name, force, yes, skip_pre, dry_run, verbosity)
                .with_context(|| format!("Failed updating package {package_name:?}"))
        }
        _ => unreachable!("The subcommand are required so this shouldn't happen."),
    }
}
