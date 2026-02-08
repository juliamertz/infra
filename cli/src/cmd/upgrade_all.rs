use std::path::PathBuf;

use anyhow::Result;
use clap::Parser;
use tokio::fs;

use crate::Context;
use crate::cmd::node::upgrade::{VersionOpt, do_upgrade};
use crate::talos;

/// Reboot and upgrade node
#[derive(Debug, Parser)]
pub struct Opts {
    #[clap(flatten)]
    version: VersionOpt,

    #[arg(long, short, default_value = "talos-customization.yaml")]
    customization_path: PathBuf,
}

pub async fn handle(ctx: Context, opts: Opts) -> Result<()> {
    let customization = fs::read_to_string(opts.customization_path).await?;
    let version = opts.version.resolved(&ctx).await?;
    let image = ctx.factory.get_image(&version, customization).await?;
    let params = talos::UpgradeParams::default();

    let members = ctx.talosctl.list_members().await?;
    for member in members.iter() {
        do_upgrade(&ctx, member, &image, &params).await?;
    }

    Ok(())
}
