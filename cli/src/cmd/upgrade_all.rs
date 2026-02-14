use std::path::PathBuf;

use anyhow::Result;
use clap::Parser;
use k8s_openapi_ext::corev1::Node;
use kube::Api;
use tokio::fs;

use crate::cmd::node::upgrade::{VersionOpt, do_upgrade};
use crate::ext::NodeApiExt;
use crate::talos;
use crate::{Context, cmd};

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

    let api = Api::<Node>::all(ctx.kube.clone());
    let members = ctx.talosctl.list_members().await?;
    for member in members.iter() {
        let node_name = member.hostname();

        cmd::node::kick_dbs::handle(ctx.clone(), member).await?;

        do_upgrade(&ctx, member, &image, &params).await?;

        api.wait_until_healthy(ctx.kube.clone(), node_name).await?;
    }

    Ok(())
}
