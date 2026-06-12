use crate::{utils::*, Prerequisites};
use semver::{Version, VersionReq};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq)]
pub struct Package {
    /// Name of the package
    pub name: String,

    #[serde(
        serialize_with = "serialize_sem_ver",
        deserialize_with = "deserialize_sem_ver"
    )]
    pub version: Version,

    #[serde(
        serialize_with = "serialize_sem_ver_req_map",
        deserialize_with = "deserialize_sem_ver_req_map"
    )]
    pub packages_deps: BTreeMap<String, VersionReq>,

    #[serde(
        serialize_with = "serialize_sem_ver_req_option",
        deserialize_with = "deserialize_sem_ver_req_option"
    )]
    pub neteye_version: Option<VersionReq>,

    pub neteye_modules: Vec<String>,
}

impl From<Prerequisites> for Package {
    fn from(value: Prerequisites) -> Self {
        // extract the version and moduels from the neteye part of the prereqs
        let (neteye_version, neteye_modules) = if let Some(neteye) = value.neteye {
            (
                Some(neteye.version),
                neteye.modules.split(",").map(str::to_string).collect(),
            )
        } else {
            (None, vec![])
        };
        // convert to a package
        Package {
            name: value.nep.name,
            version: value.nep.version,
            packages_deps: value.neteye_extension_packs,
            neteye_version,
            neteye_modules,
        }
    }
}
