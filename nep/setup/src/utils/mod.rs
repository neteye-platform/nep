use anyhow::{bail, Context, Result};
use nix::unistd::Uid;
use std::io::BufRead;
use std::path::{Path, PathBuf};
use std::process::Command;

pub(crate) mod serde_extra;
pub(crate) use serde_extra::*;

#[derive(Copy, Clone, Debug, PartialEq)]
#[repr(transparent)]
/// A sortable float, floats by default do not implement ord as due to NaNs
/// floats do not have a total order. So if we check that we don't have any
/// NaNs then it's safe to sort them.
pub(crate) struct SortableFloat(pub(crate) f64);

impl Eq for SortableFloat {}
impl PartialOrd for SortableFloat {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}
impl Ord for SortableFloat {
    #[allow(clippy::non_canonical_partial_ord_impl)] // we want total ordering on f64s
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.total_cmp(&other.0)
    }
}

/// Return a vector of all the folders inside the given path
pub fn sorted_in_folder(folder: &Path) -> Result<Vec<PathBuf>> {
    // If it does not exist then it's empty :)
    if !folder.exists() {
        log::info!("The folder {} does not exists", folder.to_str().unwrap());
        return Ok(vec![]);
    }
    // collect the subfiles and subfolders
    let mut files = vec![];
    for sub_entry in folder.read_dir()? {
        files.push(sub_entry?.path());
    }
    // sort the files for reproducitbile results
    files.sort_by_cached_key(|path| path.to_str().unwrap().to_string());
    Ok(files)
}

/// Prompt the user asking for explicit permission to proceede.
/// If the user answers `n` we will return an error, otherwise Ok.
pub fn ask_for_permission() -> Result<()> {
    let mut line = String::new();
    let stdin = std::io::stdin();
    let mut handle = stdin.lock();
    loop {
        println!("\nAre you sure? [y/n]");
        line.clear();
        let bytes_read = handle.read_line(&mut line)?;
        if bytes_read == 0 {
            bail!("Stdin was closed.")
        }
        line.make_ascii_lowercase();
        match line.trim() {
            "y" => {
                return Ok(());
            }
            "n" => {
                bail!("Exiting because the user answered no.");
            }
            line => {
                println!("Unknown input {line:?}. Answer with `y` or `n`.");
            }
        }
    }
}

/// Check that the current user is root / has root permissions
pub fn check_we_are_root() -> Result<()> {
    if !Uid::current().is_root() {
        bail!("Please run NEP as root.");
    }
    Ok(())
}

/// Run `uname -n` and return its stdout
#[cfg(target_os = "linux")]
pub(crate) fn uname_n() -> Result<String> {
    let output = Command::new("uname").arg("-n").output()?;
    let output = std::str::from_utf8(&output.stdout).with_context(|| {
        format!(
            "The output of uname -n is not a valid utf-8 str: {:?}",
            &output.stdout
        )
    })?;
    Ok(output.trim().to_string())
}

/// A port of python's `os.path.ismount` as implemented in
/// `Lib/posixpath.py` of Python 3.11:
///
/// ```python
/// def ismount(path):
///     """Test whether a path is a mount point"""
///     try:
///         s1 = os.lstat(path)
///     except (OSError, ValueError):
///         # It doesn't exist -- so not a mount point. :-)
///         return False
///     else:
///         # A symlink can never be a mount point
///         if stat.S_ISLNK(s1.st_mode):
///             return False
///
///     if isinstance(path, bytes):
///         parent = join(path, b'..')
///     else:
///         parent = join(path, '..')
///     parent = realpath(parent)
///     try:
///         s2 = os.lstat(parent)
///     except (OSError, ValueError):
///         return False
///
///     dev1 = s1.st_dev
///     dev2 = s2.st_dev
///     if dev1 != dev2:
///         return True     # path/.. on a different device as path
///     ino1 = s1.st_ino
///     ino2 = s2.st_ino
///     if ino1 == ino2:
///         return True     # path/.. is the same i-node as path
///     return False
/// ```
#[cfg(target_os = "linux")]
pub(crate) fn ismount<P: AsRef<Path>>(path: P) -> Result<bool> {
    use std::os::unix::fs::MetadataExt;
    let path = path.as_ref();

    // Get metadata for the path, handling errors
    let metadata = match std::fs::metadata(path) {
        Ok(meta) => meta,
        Err(_) => return Ok(false), // Path doesn't exist
    };

    // A symlink can never be a mount point
    if metadata.file_type().is_symlink() {
        return Ok(false);
    }

    // Get the parent path
    let parent = path.join("..").canonicalize()?;

    // Get parent metadata
    let parent_metadata = match std::fs::metadata(&parent) {
        Ok(meta) => meta,
        Err(_) => return Ok(false),
    };

    // Check if device IDs differ
    if metadata.dev() != parent_metadata.dev() {
        return Ok(true); // Different devices = mount point
    }

    // Check if inode numbers are the same
    if metadata.ino() == parent_metadata.ino() {
        return Ok(true); // Same inode = mount point (path/.. is same as path)
    }

    Ok(false)
}
