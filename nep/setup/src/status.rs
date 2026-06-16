use clap::ValueEnum;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[non_exhaustive]
pub enum Status {
    /// The package is already installed and at the leastest version
    Installed,
    /// The package is not installed.
    Available,
    /// The package is already installed and it can be updated
    Updatable,

    /// The package has errors
    Errored,
    /// This package is not yet installed but it has errors
    AvailableErrored,
    /// This package is installed and we have a new version but the newer version has errors
    UpdatableErrored,
}

#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum)]
#[non_exhaustive]
pub enum StatusFilter {
    All,
    Installed,
    Available,
    Updatable,
    Errored,
}

impl StatusFilter {
    #[must_use]
    pub(crate) fn filter(&self, other: Status) -> bool {
        matches!(
            (self, other),
            (StatusFilter::All, _)
                | (StatusFilter::Installed, Status::Installed)
                | (StatusFilter::Available, Status::Available)
                | (StatusFilter::Updatable, Status::Updatable)
                | (StatusFilter::Errored, Status::Errored)
        )
    }
}
