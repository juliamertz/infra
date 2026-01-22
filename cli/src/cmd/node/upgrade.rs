use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context as _, Result, bail};
use clap::Parser;
use k8s_openapi_ext::corev1::Node;
use kube::Api;
use tokio::{fs, time::sleep};
use tracing::info;

use crate::Context;
use crate::ext::NodeApiExt;

/// Reboot and upgrade node
#[derive(Debug, Parser)]
pub struct Opts {
    #[arg(long, default_value_t = false)]
    latest: bool,

    #[arg(long, short)]
    version: Option<String>,

    #[arg(long, short)]
    customization_path: Option<PathBuf>,
}

pub async fn handle(ctx: Context, opts: Opts, node_name: &str) -> Result<()> {
    let customization_path = opts
        .customization_path
        .unwrap_or_else(|| "talos-customization.yaml".into());

    let member = ctx
        .talosctl
        .member(node_name)
        .context("node not found")?;
    let node_name = &member.hostname();
    let node_ip = member
        .external_ip()
        .context("cannot find external ip for member")?;

    let version = if opts.latest && opts.version.is_some() {
        bail!("'latest' and 'version' arguments are mutually exclusive");
    } else if opts.latest {
        ctx.factory.latest_version().await?
    } else if let Some(version) = opts.version {
        version
    } else {
        bail!("specify either the 'version' or 'latest' flag");
    };

    info!("Upgrading {node_name} () to version {version}");

    let nodes = Api::<Node>::all(ctx.kube);

    let is_cordoned = nodes
        .get(node_name)
        .await
        .expect("node to exist")
        .spec
        .unwrap_or_default()
        .taints
        .unwrap_or_default()
        .into_iter()
        .any(|taint| {
            taint.key == "node.kubernetes.io/unschedulable" && taint.effect == "NoSchedule"
        });

    let customization = fs::read_to_string(&customization_path).await?;
    let image = ctx.factory.get_image(&version, customization).await?;
    let params = crate::talos::UpgradeParams::default();
    ctx.talosctl
        .upgrade_member(node_ip, &image, &params)
        .await?;

    loop {
        if nodes.is_ready(node_name).await {
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
