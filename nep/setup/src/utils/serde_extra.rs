//! Add serde Serializers and Deserializers for semantic versioning
//!
//! Example of usage:
//! ```ignore
//! #[derive(Serialize, Deserialize)]
//! struct MyStruct {
//!     #[serde(rename="nep-common", serialize_with="serialize_sem_ver_req", deserialize_with="deserialize_sem_ver_req")]
//!     pub nep_common: VersionReq,
//! }
//! ```
use semver::{Version, VersionReq};
use serde::de::Error;
use serde::ser::SerializeMap;
use serde::{Deserialize, Deserializer, Serializer};
use std::collections::BTreeMap;

#[allow(dead_code)]
pub(crate) fn serialize_sem_ver<S>(value: &Version, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_str(&value.to_string())
}

#[allow(dead_code)]
pub(crate) fn deserialize_sem_ver<'de, D>(deserializer: D) -> Result<Version, D::Error>
where
    D: Deserializer<'de>,
{
    let s: &str = Deserialize::deserialize(deserializer)?;
    Version::parse(s).map_err(|err| D::Error::custom(err.to_string()))
}

#[allow(dead_code)]
pub(crate) fn serialize_sem_ver_req<S>(value: &VersionReq, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_str(&value.to_string())
}

#[allow(dead_code)]
pub(crate) fn deserialize_sem_ver_req<'de, D>(deserializer: D) -> Result<VersionReq, D::Error>
where
    D: Deserializer<'de>,
{
    let s: &str = Deserialize::deserialize(deserializer)?;
    VersionReq::parse(s).map_err(|err| D::Error::custom(err.to_string()))
}

#[allow(dead_code)]
pub(crate) fn serialize_sem_ver_req_option<S>(
    value: &Option<VersionReq>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    if let Some(version) = value {
        serializer.serialize_some(&version.to_string())
    } else {
        serializer.serialize_none()
    }
}

#[allow(dead_code)]
pub(crate) fn deserialize_sem_ver_req_option<'de, D>(
    deserializer: D,
) -> Result<Option<VersionReq>, D::Error>
where
    D: Deserializer<'de>,
{
    let s: Option<&str> = Deserialize::deserialize(deserializer)?;
    if let Some(s) = s {
        Ok(Some(
            VersionReq::parse(s).map_err(|err| D::Error::custom(err.to_string()))?,
        ))
    } else {
        Ok(None)
    }
}

#[allow(dead_code)]
pub(crate) fn serialize_sem_ver_req_map<S>(
    value: &BTreeMap<String, VersionReq>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let mut s = serializer.serialize_map(Some(value.len()))?;
    for (k, v) in value {
        s.serialize_entry(k, &v.to_string())?;
    }
    s.end()
}

#[allow(dead_code)]
pub(crate) fn deserialize_sem_ver_req_map<'de, D>(
    deserializer: D,
) -> Result<BTreeMap<String, VersionReq>, D::Error>
where
    D: Deserializer<'de>,
{
    let s: BTreeMap<&str, &str> = Deserialize::deserialize(deserializer)?;
    let mut res = BTreeMap::new();
    for (k, v) in s {
        let r = res.insert(
            k.to_string(),
            VersionReq::parse(v).map_err(|err| D::Error::custom(err.to_string()))?,
        );
        assert!(r.is_none())
        // TODO!: if the result of insert is some, then there are duplicates
        // and we should break, but how can I return an err compatible with
        // the generic type D?
    }
    Ok(res)
}
