use std::path::{Path, PathBuf};
use std::process::Stdio;

use common::proxy_stdio;
use kube::api::DynamicObject;
use serde::Deserialize;
use tokio::fs;
use tokio::process::Command;
use tracing::{info, instrument};

use crate::sync::vals;

#[derive(Debug, thiserror::Error)]
pub enum BuildError {
    #[error("vals error: {0}")]
    Vals(#[from] vals::Error),
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("exited: {0:?}")]
    Exit(std::process::ExitStatus),
}

pub type BuildResult<T> = core::result::Result<T, BuildError>;

#[instrument(err(Debug))]
pub async fn build(dir: &Path, attrpath: &str) -> BuildResult<PathBuf> {
    info!("starting nix build");
    let mut root_cmd = Command::new("nix");
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
    proxy_stdio(child.stdout.take().unwrap());
    proxy_stdio(child.stderr.take().unwrap());

    let status = child.wait().await?;
    if status.success() {
        let out_path = fs::read_link(dir.join("result")).await?;
        info!({ ?out_path }, "build successful");
        Ok(out_path)
    } else {
        Err(BuildError::Exit(status))
    }
}

#[derive(Debug, Deserialize)]
struct ObjectList {
    items: Vec<DynamicObject>,
}

#[instrument(err(Debug))]
pub async fn build_kubenix(
    dir: &Path,
    attrpath: &str,
) -> BuildResult<Vec<DynamicObject>> {
    let out_path = build(dir, attrpath).await?;
    let content = fs::read_to_string(&out_path).await?;
    let templated = vals::eval(&dir, &content).await?;
    Ok(serde_json::from_str::<ObjectList>(&templated)?.items)
}
