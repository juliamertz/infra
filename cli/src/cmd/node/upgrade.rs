use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context as _, Result, bail};
use clap::Parser;
use k8s_openapi_ext::corev1::Node;
use kube::Api;
use tokio::{fs, time::sleep};
use tracing::{info, instrument};

use crate::ext::NodeApiExt;
use crate::talos::Member;
use crate::{Context, talos};

#[derive(Debug, Parser)]
pub struct VersionOpt {
    #[arg(long, default_value_t = false)]
    pub latest: bool,

    #[arg(long, short)]
    pub version: Option<String>,
}

impl VersionOpt {
    pub async fn resolved(&self, ctx: &Context) -> Result<String> {
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

    #[arg(long, short, default_value = "talos-customization.yaml")]
    customization_path: PathBuf,
}

pub async fn handle(ctx: Context, opts: Opts, node_name: &str) -> Result<()> {
    let customization = fs::read_to_string(opts.customization_path).await?;
    let member = ctx.talosctl.member(node_name).context("node not found")?;
    let version = opts.version.resolved(&ctx).await?;
    let image = ctx.factory.get_image(&version, customization).await?;
    let params = talos::UpgradeParams::default();

    do_upgrade(&ctx, member, &image, &params).await
}

#[instrument(skip_all, err(Debug), fields(member = member.hostname(), version = &image.version))]
pub async fn do_upgrade(
    ctx: &Context,
    member: &Member,
    image: &talos::Image,
    params: &talos::UpgradeParams,
) -> Result<()> {
    let nodes = Api::<Node>::all(ctx.kube.clone());
    let name = member.hostname();
    let ip = member
        .external_ip()
        .context("no external ip found for member")?;

    let is_cordoned = nodes.is_cordoned(name).await?;

    ctx.talosctl.upgrade_member(ip, image, params).await?;

    loop {
        if nodes.is_ready(name).await? {
            info!("node ready");
            if !is_cordoned {
                nodes.uncordon(name).await?;
            };

            break Ok(());
        } else {
            info!("node not ready");
            let timeout = Duration::from_secs(1);
            sleep(timeout).await;
        }
    }
}
