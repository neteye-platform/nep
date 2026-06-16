use super::*;
use crate::utils::{ismount, uname_n};
use anyhow::{anyhow, bail, Context, Result};
use semver::Version;
use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

/// The type of node (server)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NodeType {
    /// The cluster master node (or only node in a single node cluster)
    Master,
    /// A node that can vote in the cluster
    Node,
    /// A node that can only vote in the cluster
    VotingOnly,
    /// A node that can only be used for elastic search
    ElasticOnly,
    // Satellites are not here as we cannot guarantee that we can ssh into them
    Satellite,
    /// Single node
    SingleNode,
}

impl NodeType {
    pub fn is_local(&self) -> bool {
        matches!(
            self,
            NodeType::Master | NodeType::Satellite | NodeType::SingleNode
        )
    }
}

impl core::fmt::Display for NodeType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            NodeType::Master => write!(f, "master"),
            NodeType::Node => write!(f, "node"),
            NodeType::VotingOnly => write!(f, "voting_only"),
            NodeType::ElasticOnly => write!(f, "elastic_only"),
            NodeType::Satellite => write!(f, "satellite"),
            NodeType::SingleNode => write!(f, "single_node"),
        }
    }
}

#[derive(Debug, Clone, Hash)]
/// Collection of **all** the paths we will use
pub struct Confs {
    /// The path where neteye writes the other nodes informations on a cluster
    pub neteye_cluster_file: PathBuf,
    /// The file present on satellite nodes
    pub neteye_satellite_file: PathBuf,
    /// Nep from RPM with the packages that can be installed to update to a
    /// newer version
    pub stage: PathBuf,
    /// drbd mount, shared between nodes, ignore plz, only used to check
    /// which node is the master one
    pub packages_root: PathBuf,
    /// Historical folder where each package has subfolder with all the
    /// versions that were found, with v.{version}
    pub packages: PathBuf,
    /// Path to the fs packages
    pub fs_packages_file: PathBuf,
    /// Working dir, this is either stage or the last versioned package
    /// depending on installation or reinstallation
    pub working_dir: PathBuf,
}

impl std::default::Default for Confs {
    fn default() -> Self {
        Confs {
            neteye_cluster_file: PathBuf::from_str("/etc/neteye-cluster").unwrap(),
            neteye_satellite_file: PathBuf::from_str("/etc/neteye-satellite").unwrap(),
            stage: PathBuf::from_str("/usr/share/neteye/nep/").unwrap(),
            working_dir: PathBuf::from_str("/usr/share/neteye/nep/").unwrap(),
            packages_root: PathBuf::from_str("/neteye/shared/nep/").unwrap(),
            packages: PathBuf::from_str("/neteye/shared/nep/data/packages/").unwrap(),
            fs_packages_file: PathBuf::from_str(
                "/usr/share/neteye/nep/setup/conf/fs_packages.json",
            )
            .unwrap(),
        }
    }
}

impl Confs {
    /// Create a new confs from the base
    pub fn new(
        stage: PathBuf,
        packages: PathBuf,
        neteye_cluster_file: PathBuf,
        fs_packages_file: PathBuf,
    ) -> Result<Self> {
        if !stage.exists() {
            bail!("The stage folder doesn't exists: {:?}", stage);
        }
        if !packages.exists() {
            bail!("The packages folder doesn't exists: {:?}", packages);
        }
        //if !neteye_cluster_file.exists() {
        //    bail!("The neteye_cluster_file folder doesn't exists: {:?}", neteye_cluster_file);
        //}
        if !fs_packages_file.exists() {
            bail!(
                "The fs_packages_file folder doesn't exists: {:?}",
                fs_packages_file
            );
        }

        Ok(Confs {
            working_dir: stage.clone(),
            stage,
            packages,
            neteye_cluster_file,
            fs_packages_file,
            ..Default::default()
        })
    }

    pub fn get_packages(&self, installed_packages: &BTreeMap<String, Version>) -> Result<Packages> {
        let mut result = Packages::default();

        for (name, obj) in get_packages_in_path(&self.stage) {
            match obj {
                Ok(package) => {
                    if let Some(installed_version) = installed_packages.get(&name) {
                        match installed_version.cmp(&package.version) {
                            std::cmp::Ordering::Greater | std::cmp::Ordering::Equal => {
                                if result.installed.insert(name.clone(), package).is_some() {
                                    bail!("Duplicated install package {:?}", name);
                                }
                            }
                            std::cmp::Ordering::Less => {
                                if result.updatable.insert(name.clone(), package).is_some() {
                                    bail!("Duplicated updatable package {:?}", name);
                                }
                            }
                        }
                    } else if result.available.insert(name.clone(), package).is_some() {
                        bail!("Duplicated available package {:?}", name);
                    }
                }
                Err(e) => {
                    if result.errored.insert(name.clone(), e).is_some() {
                        bail!("Duplicated errored package {:?}", name);
                    }
                }
            }
        }

        Ok(result)
    }

    /// Identify if the current machine is a cluster
    /// On netye systems the file [`NETEYE_CLUSTER_FILE`] contains the ips of the
    /// other machines in the cluster.
    #[must_use]
    pub fn is_cluster(&self) -> bool {
        self.neteye_cluster_file.is_file()
    }

    #[inline(always)]
    /// Check that we are on the master node by checking that packages_root is
    /// a mounted disk
    pub fn is_nep_master(&self) -> Result<bool> {
        ismount(&self.packages_root)
    }

    /// Identify if the current machine is a satellite
    #[must_use]
    pub fn is_satellite(&self) -> bool {
        self.neteye_satellite_file.is_file()
    }

    /// either run `uname -n` or read the `Hostname` field from [`self.neteye_cluster_file`]
    pub fn get_neteye_hostname(&self) -> Result<String> {
        uname_n()
    }

    /// Read /etc/neteye-cluster to figure out the nodes in the cluster
    ///
    pub fn get_neteye_nodes(&self) -> Result<BTreeMap<String, NodeType>> {
        let mut res = BTreeMap::new();
        let master_hostname = self.get_neteye_hostname()?;
        if !self.is_cluster() {
            //bail!("You can't ask for the neteye nodes on a non-cluster node.");
            if self.is_satellite() {
                res.insert(master_hostname, NodeType::Satellite);
            } else {
                res.insert(master_hostname, NodeType::SingleNode);
            }
            return Ok(res);
        }
        let data = std::fs::read_to_string(&self.neteye_cluster_file).with_context(|| {
            format!(
                "Cannot read the {} file",
                self.neteye_cluster_file.to_string_lossy()
            )
        })?;

        log::trace!(
            "The content of '{}' is: {}",
            self.neteye_cluster_file.to_str().unwrap(),
            &data
        );

        // parse the json
        let v: serde_json::Value = serde_json::from_str(&data)
            .with_context(|| "The neteye-cluster file is not a valid json file")?;
        let obj = v.as_object().ok_or(anyhow!(
            "The neteye-cluster file is a valid json but it's not an object!"
        ))?;

        // obj["Nodes"]
        let nodes = obj.get("Nodes").ok_or(anyhow!("Nodes field not present"))?;
        let nodes = nodes
            .as_array()
            .ok_or(anyhow!("The Nodes field is not an array"))?;

        // extract the string fields
        for node in nodes.iter() {
            let node = node.as_object().unwrap();

            match node.get("hostname_ext") {
                Some(hostname_ext) => {
                    let hostname_ext = hostname_ext.as_str().unwrap();
                    if res
                        .insert(hostname_ext.to_string(), NodeType::Node)
                        .is_some()
                    {
                        log::warn!("The node hostname '{hostname_ext}' is present multiple times!");
                    }
                }
                None => {
                    bail!(
                        "The following cluster node does not contains the required 'hostname_ext' field: {}",
                        serde_json::to_string_pretty(node)?,
                    );
                }
            }
        }

        if let Some(voting) = obj.get("VotingOnlyNode") {
            let voting = voting
                .as_object()
                .ok_or(anyhow!("VotingOnlyNode is not an object"))?;
            let hostname = voting
                .get("hostname_ext")
                .ok_or(anyhow!("VotingOnlyNode does not contain hostname_ext"))?;
            let hostname = hostname
                .as_str()
                .ok_or(anyhow!("VotingOnlyNode hostname_ext is not a string"))?;
            res.insert(hostname.to_string(), NodeType::VotingOnly);
        }

        if let Some(elastic) = obj.get("ElasticOnlyNodes") {
            let elastic = elastic
                .as_array()
                .ok_or(anyhow!("ElasticOnlyNodes is not an array"))?;
            for node in elastic.iter() {
                let node = node
                    .as_object()
                    .ok_or(anyhow!("ElasticOnlyNodes element is not an object"))?;
                let hostname = node.get("hostname_ext").ok_or(anyhow!(
                    "ElasticOnlyNodes element does not contain hostname_ext"
                ))?;
                let hostname = hostname.as_str().ok_or(anyhow!(
                    "ElasticOnlyNodes element hostname_ext is not a string"
                ))?;
                res.insert(hostname.to_string(), NodeType::ElasticOnly);
            }
        }

        // Ensure that the master is present
        res.entry(master_hostname).or_insert(NodeType::Master);
        log::trace!("Found nodes hostnames '{:?}' ", &res);
        Ok(res)
    }
}
