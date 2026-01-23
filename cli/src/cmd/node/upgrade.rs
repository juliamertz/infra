use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context as _, Result, bail};
use clap::Parser;
use k8s_openapi_ext::corev1::Node;
use kube::Api;
use tokio::{fs, time::sleep};
use tracing::info;

use crate::ext::NodeApiExt;
use crate::{Context, talos};

#[derive(Debug, Parser)]
pub struct VersionOpt {
    #[arg(long, default_value_t = false)]
    pub latest: bool,

    #[arg(long, short)]
    pub version: Option<String>,
}

impl VersionOpt {
    async fn resolved(&self, ctx: &Context) -> Result<String> {
        if self.latest && self.version.is_some() {
            bail!("'latest' and 'version' flags are mutually exclusive");
        } else if self.latest {
            ctx.factory.latest_version().await
        } else if let Some(version) = self.version.clone() {
            Ok(version)
        } else {
            bail!("specify either the 'version' or 'latest' flag");
        }
    }
}

/// Reboot and upgrade node
#[derive(Debug, Parser)]
pub struct Opts {
    #[clap(flatten)]
    version: VersionOpt,

    #[arg(long, short)]
    customization_path: Option<PathBuf>,
}

pub async fn handle(ctx: Context, opts: Opts, node_name: &str) -> Result<()> {
    let customization = fs::read_to_string(
        opts.customization_path
            .unwrap_or_else(|| "talos-customization.yaml".into()),
    )
    .await?;

    let version = opts.version.resolved(&ctx).await?;
    let member = ctx.talosctl.member(node_name).context("node not found")?;
    let node_name = &member.hostname();
    let node_ip = member
        .external_ip()
        .context("cannot find external ip for member")?;
    let image = ctx.factory.get_image(&version, customization).await?;

    info!("Upgrading {node_name} ({node_ip}) to version {version}");

    let nodes = Api::<Node>::all(ctx.kube);
    let is_cordoned = nodes.is_cordoned(node_name).await?;

    let params = talos::UpgradeParams::default();
    ctx.talosctl
        .upgrade_member(node_ip, &image, &params)
        .await?;

    loop {
        if nodes.is_ready(node_name).await? {
            info!("node ready");
            if !is_cordoned {
                nodes.uncordon(node_name).await?;
            };

            break Ok(());
        } else {
            info!("node not ready");
            let timeout = Duration::from_secs(1);
            sleep(timeout).await;
        }
    }
}
