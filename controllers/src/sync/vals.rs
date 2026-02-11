use std::path::Path;
use std::process::{ExitStatus, Stdio};

use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tracing::debug;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
    #[error("vals exited with status {status:?}, stderr: {stderr}")]
    Exit { status: ExitStatus, stderr: String },
}

pub type Result<T, E = Error> = core::result::Result<T, E>;

pub async fn eval(
    working_directory: &Path,
    content: impl AsRef<[u8]>,
) -> Result<String, Error> {
    let mut root_cmd = Command::new("vals");
    let cmd = root_cmd
        .current_dir(working_directory)
        .env("SOPS_AGE_KEY_FILE", "/etc/sops/age/keys.txt")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .arg("eval")
        .arg("-o")
        .arg("json")
        .arg("-f")
        .arg("-");

    debug!("spawning vals for sops substitution");

    let mut child = cmd.spawn()?;
    let mut stdin = child.stdin.take().unwrap();
    stdin.write_all(content.as_ref()).await?;
    stdin.flush().await?;
    drop(stdin);

    let output = child.wait_with_output().await?;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(stdout.to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        Err(Error::Exit {
            status: output.status,
            stderr,
        })
    }
}
