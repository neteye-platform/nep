use crate::*;
use rand::Rng;
use std::collections::BTreeMap;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// Result of a shell command execution.
#[derive(Debug)]
pub struct ExecutionResult {
    pub status: std::process::ExitStatus,
    pub stdout: String,
    pub stderr: String,
}

/// Wrapper that handles the copy of files between nodes and the execution of
/// commands on nodes.
#[derive(Debug)]
pub struct ExecEnv {
    children: BTreeMap<String, NodeType>,
    hostname: String,
    hosttype: NodeType,
}

impl ExecEnv {
    pub fn new(confs: &Confs) -> Result<Self> {
        // get the nodes in the cluster
        let mut children: BTreeMap<String, NodeType> =
            confs.get_neteye_nodes()?.into_iter().collect();

        // remove the current node (THAT HAS TO BE THE MASTER) form the children
        let hostname = confs.get_neteye_hostname()?;
        let hosttype = children.remove(&hostname).unwrap();

        // create the env so we can use it for the consistency check
        let exec_env = Self {
            children,
            hostname,
            hosttype,
        };

        // Check that the neteye-nep rpm installed is the same on all the nodes
        let results = exec_env.exec_all("rpm", &["-q", "neteye-nep"], None)?;
        if let Some((_, first)) = results.first_key_value() {
            if !results
                .values()
                .all(|v| v.stdout.trim() == first.stdout.trim())
            {
                let mut res = String::new();
                for (node, status) in results.iter() {
                    res.push_str(&format!("\t{} : {}\n", node, status.stdout));
                }

                bail!(
                    "The neteye-nep RPM version is not consistent between all nodes. {}",
                    res,
                );
            }
        }

        Ok(exec_env)
    }

    pub fn get_host(&self) -> (&String, &NodeType) {
        (&self.hostname, &self.hosttype)
    }

    /// Get the path to a random folder we can use as scratch.
    /// Currently it check it doesn't exists on this node, but it doesn't check
    /// all the other nodes
    pub fn random_folder(&mut self) -> PathBuf {
        // prob di collisione = 16^(-64) = 8.636168555094445*^-78 GOOD ENOUGH for me
        const HEX_CHARS: &[u8] = b"0123456789abcdef";
        const PATH_LEN: usize = 64;
        let mut rng = rand::thread_rng();
        let mut path = vec![0; PATH_LEN];
        loop {
            // gen new path
            (0..PATH_LEN).for_each(|i| {
                path[i] = HEX_CHARS[rng.gen_range(0..HEX_CHARS.len() - 1)];
            });
            // convert to string
            let path_str = String::from_utf8(path.clone()).unwrap(); // TODO: remove useless clone
                                                                     // create a path
            let mut abs_path = PathBuf::new();
            abs_path.extend(["/tmp".into(), "nep".into(), path_str]);
            log::debug!("Generated random folder: {abs_path:?}");

            if abs_path.exists() {
                continue;
            }

            return abs_path;
        }
    }

    /// Copy local files to a local folder
    pub fn sync_files_master(&mut self, local_src: &Path, local_dst: &str) -> Result<()> {
        if !local_src.exists() {
            return Ok(());
        }

        self.exec_master(
            "rsync",
            &[
                "-a",
                "--exclude='*.md'",
                &format!("{}/", local_src.to_str().unwrap()),
                local_dst,
            ],
            None,
        )?;

        Ok(())
    }

    /// Copy local files to a given endpoint filesystem
    pub fn sync_files_endpoint(
        &mut self,
        endpoint: &str,
        local_src: &Path,
        remote_dst: &str,
    ) -> Result<()> {
        if !local_src.exists() {
            return Ok(());
        }

        let local_src = local_src.to_str().unwrap();
        // StrictHostKeyChecking=no is needed because a service might migrate
        // to a different node so the known_hosts key would be outdated and
        // crash.
        self.exec_master(
            "bash",
            &[
                "-c",
                &format!(
                    "rsync -a --exclude='*.md' -e \"ssh -o StrictHostKeyChecking=no\" {}/ {}",
                    local_src,
                    &format!("{endpoint}:{remote_dst}")
                ),
            ],
            None,
        )?;

        Ok(())
    }

    /// Copy files from this with all nodes, (master and remotes)
    pub fn sync_files_all(&mut self, local_src: &Path, remote_dst: &str) -> Result<()> {
        if !local_src.exists() {
            return Ok(());
        }
        self.sync_files_master(local_src, remote_dst)?;

        let names = self
            .children
            .keys()
            .map(|x| x.to_string())
            .collect::<Vec<_>>();

        for node_name in names {
            self.sync_files_endpoint(&node_name, local_src, remote_dst)?;
        }

        Ok(())
    }

    /// Execute a command on the master node and return stdout, stderr, and status
    pub fn exec_master(
        &self,
        command: &str,
        args: &[&str],
        stdin_body: Option<&[u8]>,
    ) -> Result<ExecutionResult> {
        log::debug!("Executing: '{}' {}", command, args.iter().map(|x| format!("'{}'", x)).collect::<Vec<_>>().join(" "));
        log::trace!(
            "stdin: {:?}",
            stdin_body.map(|s| String::from_utf8_lossy(s))
        );
        // spawn the process and pipe all stdinos
        let mut child = Command::new(command)
            .args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        // send the body to the process stdin
        let mut stdin = child.stdin.take().unwrap();
        if let Some(stdin_body) = stdin_body {
            stdin.write_all(stdin_body)?;
            stdin.flush()?;
        }
        // force drop so the file descriptor is closed
        // and the program will exit so we can continue
        drop(stdin);
        let output = child.wait_with_output()?;
        // Extract the outputs
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        log::debug!("Got exit code: {}", output.status);
        log::trace!("Got stdout: {stdout}");
        log::trace!("Got stderr: {stderr}");

        if !output.status.success() {
            // TODO!: should I add stderr and stdout to the error?
            bail!(
                "Got bad exit code during execution of command: {} {}",
                command,
                args.join(" ")
            );
        }

        Ok(ExecutionResult {
            status: output.status,
            stdout,
            stderr,
        })
    }

    /// execute a command on a given endpoint.
    pub fn exec_endpoint(
        &self,
        endpoint: &str,
        command: &str,
        args: &[&str],
        stdin_body: Option<&[u8]>,
    ) -> Result<ExecutionResult> {
        // to execute the command we are going to setup an ssh command forwarding the data
        let endpoint = format!("root@{endpoint}");
        let mut inner_args = vec![endpoint.as_str()];
        inner_args.push("-o StrictHostKeyChecking=no"); // same reason described in [`sync_files_endpoint`]
        inner_args.push(command);
        inner_args.extend_from_slice(args);

        self.exec_master("ssh", &inner_args, stdin_body)
    }

    /// Execute command on all nodes (master & remotes) and return a map of
    /// `node_name -> execution result`, the master node is just called "master"
    pub fn exec_all(
        &self,
        command: &str,
        args: &[&str],
        stdin_body: Option<&[u8]>,
    ) -> Result<BTreeMap<String, ExecutionResult>> {
        let mut res = BTreeMap::new();
        // TODO!: should I change this to get_hostname()?
        res.insert(
            "master".into(),
            self.exec_master(command, args, stdin_body)?,
        );
        for node in self.children.clone().keys() {
            res.insert(
                node.clone(),
                self.exec_endpoint(node, command, args, stdin_body)?,
            );
        }
        Ok(res)
    }
}
