use std::path::{Path, PathBuf};
use std::process::Stdio;

use common::proxy_stdio;
use kube::api::DynamicObject;
use serde::{Deserialize, Serialize};
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
    #[error("invalid utf8: {0}")]
    FromUtf8(#[from] std::str::Utf8Error),
    #[error("exited: {0:?}")]
    Exit(std::process::ExitStatus),
}

pub type BuildResult<T> = core::result::Result<T, BuildError>;

struct NixConfig {
    build_users_group: String,
    extra_experimental_features: Vec<String>,
}

impl std::fmt::Display for NixConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!(
            "build-users-group = {}\n",
            self.build_users_group
        ))?;
        f.write_fmt(format_args!(
            "extra-experimental-features = {}\n",
            self.extra_experimental_features.join(" ")
        ))
    }
}

impl Default for NixConfig {
    fn default() -> Self {
        Self {
            build_users_group: "".into(),
            extra_experimental_features: ["nix-command", "flakes", "pipe-operators"]
                .into_iter()
                .map(Into::into)
                .collect(),
        }
    }
}

#[instrument(err(Debug))]
pub async fn build(dir: &Path, attrpath: &str) -> BuildResult<PathBuf> {
    info!("starting nix build");
    let mut root_cmd = Command::new("nix");
    let cmd = root_cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .current_dir(dir)
        .env("NIX_CONFIG", NixConfig::default().to_string())
        .arg("build")
        .arg(attrpath);

    let tmp_path: &Path = "/tmp".as_ref();
    if !tmp_path.exists() {
        fs::create_dir(tmp_path).await?;
    }

    let mut child = cmd.spawn()?;
    proxy_stdio(child.stdout.take().unwrap());
    proxy_stdio(child.stderr.take().unwrap());

    let output = child.wait_with_output().await?;
    if output.status.success() {
        let out_path = fs::read_link(dir.join("result")).await?;
        info!({ ?out_path }, "build successful");
        Ok(out_path)
    } else {
        Err(BuildError::Exit(output.status))
    }
}

#[derive(Debug, Deserialize)]
struct ObjectList {
    items: Vec<DynamicObject>,
}

#[instrument(err(Debug))]
pub async fn build_kubenix(dir: &Path, attrpath: &str) -> BuildResult<Vec<DynamicObject>> {
    let out_path = build(dir, attrpath).await?;
    let content = fs::read_to_string(&out_path).await?;
    let templated = vals::eval(&dir, &content).await?;
    Ok(serde_json::from_str::<ObjectList>(&templated)?.items)
}
