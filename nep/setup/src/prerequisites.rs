use crate::utils::*;
use anyhow::Result;
use semver::{Version, VersionReq};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Serialize, Deserialize)]
pub struct Prerequisites {
    #[serde(rename = "NEP")]
    pub nep: NepConf,

    #[serde(rename = "NetEye")]
    pub neteye: Option<NetEye>,

    #[serde(rename = "NetEyeExtensionPacks")]
    #[serde(
        serialize_with = "serialize_sem_ver_req_map",
        deserialize_with = "deserialize_sem_ver_req_map"
    )]
    pub neteye_extension_packs: BTreeMap<String, VersionReq>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NepConf {
    pub name: String,
    #[serde(
        serialize_with = "serialize_sem_ver",
        deserialize_with = "deserialize_sem_ver"
    )]
    pub version: Version,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NetEye {
    #[serde(
        serialize_with = "serialize_sem_ver_req",
        deserialize_with = "deserialize_sem_ver_req"
    )]
    pub version: VersionReq,
    pub modules: String,
}

impl Prerequisites {
    pub fn open<P: AsRef<Path>>(path: &P) -> Result<Prerequisites> {
        let text = std::fs::read_to_string(path.as_ref()).unwrap();
        toml::from_str(&text).map_err(anyhow::Error::from)
    }
}
