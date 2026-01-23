use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context as _, Result, bail};
use clap::Parser;
use k8s_openapi_ext::corev1::Node;
use kube::Api;
use tokio::{fs, time::sleep};
use tracing::info;

use crate::Context;
use crate::cmd::node::upgrade::VersionOpt;
use crate::ext::NodeApiExt;

/// Reboot and upgrade node
#[derive(Debug, Parser)]
pub struct Opts {
    #[clap(flatten)]
    version: VersionOpt,

    #[arg(long, short)]
    customization_path: Option<PathBuf>,
}

pub async fn handle(ctx: Context, opts: Opts) -> Result<()> {
    let members = ctx.talosctl.list_members().await?;

    dbg!(&opts);

    for member in members {
        dbg!(&member.hostname());
    }

    Ok(())
}
