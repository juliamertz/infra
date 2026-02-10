use std::io::stdin;
use std::path::{Path, PathBuf};
use std::process::Stdio;

use serde::Deserialize;
use tokio::fs;
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncWriteExt, BufReader};
use tracing::{debug, info, instrument};

fn proxy_stdio<R>(reader: R)
where
    R: AsyncRead + Unpin + Send + 'static,
{
    let mut lines = BufReader::new(reader).lines();

    tokio::spawn(async move {
        while let Ok(Some(line)) = lines.next_line().await {
            debug!("{line}")
        }
    });
}

#[derive(Debug, thiserror::Error)]
pub enum BuildError {
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("exited: {0:?}")]
    Exit(std::process::ExitStatus),
}

#[instrument(err(Debug))]
pub async fn build(dir: &Path, attrpath: &str) -> Result<PathBuf, BuildError> {
    info!("starting nix build");
    let mut root_cmd = tokio::process::Command::new("nix");
    let cmd = root_cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .current_dir(dir)
        .env("NIX_CONFIG", "build-users-group = ")
        .arg("--extra-experimental-features")
        .arg("nix-command flakes pipe-operators")
        .arg("build")
        .arg(attrpath);

    let tmp_path: &Path = "/tmp".as_ref();
    if !tmp_path.exists() {
        fs::create_dir(tmp_path).await?;
    }

    let mut child = cmd.spawn()?;

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    proxy_stdio(stdout);
    proxy_stdio(stderr);

    let status = child.wait().await?;

    if status.success() {
        let out_path = fs::read_link(dir.join("result")).await?;
        info!({ ?out_path }, "build successful");
        Ok(out_path)
    } else {
        Err(BuildError::Exit(status))
    }
}

async fn substitute_vars(content: impl AsRef<[u8]>) -> Result<String, anyhow::Error> {
    let mut root_cmd = tokio::process::Command::new("vals");
    let cmd = root_cmd
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .env("SOPS_AGE_KEY_FILE", "/etc/sops/age/keys.txt")
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
        todo!()
    }
}

#[derive(Debug, Deserialize)]
struct ObjectList {
    items: Vec<kube::api::DynamicObject>,
}

#[instrument(err(Debug))]
pub async fn build_kubenix(
    dir: &Path,
    attrpath: &str,
) -> Result<Vec<kube::api::DynamicObject>, BuildError> {
    let out_path = build(dir, attrpath).await?;
    let content = fs::read_to_string(&out_path).await?;
    let templated = substitute_vars(&content).await.unwrap();
    Ok(serde_json::from_str::<ObjectList>(&templated)?.items)
}
