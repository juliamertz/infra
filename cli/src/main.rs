use std::time::Duration;

use anyhow::{Context, Result};
use clap::Parser;

mod cluster;
mod jlib;
mod prompt;
mod talos;

use cluster::Cluster;
use k8s_openapi_ext::corev1::{Node, Pod};
use kube::{Api, ResourceExt, api::ListParams};
use prompt::confirm;
use talos::TalosFactory;
use tokio::{process::Command, time::sleep};
use tracing::{Level, error, info, info_span, instrument, span, warn};
use version_compare::Version;

use crate::talos::{Member, TalosCtl, UpgradeParams};

#[derive(Parser)]
struct Opts {
    #[arg(long, short)]
    node: String,

    #[command(subcommand)]
    command: Subcommand,
}

#[derive(Debug, clap::Subcommand)]
enum Subcommand {
    /// Evict all pods and prepare node for upgrade
    Drain,
    /// Reboot and upgrade node
    Upgrade,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let opts = Opts::parse();
    let kube = kube::Client::try_default().await?;

    let nodes = Api::<Node>::all(kube);
    let factory = TalosFactory::default();
    let talosctl = TalosCtl::try_new().await?;

    let member = talosctl.member(&opts.node).context("node not found")?;
    let node_name = &member.spec.hostname;
    let node_ip = member
        .external_ip()
        .context("cannot find external ip for member")?;

    match opts.command {
        Subcommand::Drain => {
            nodes.cordon(node_name).await?;
            drain_node(node_name).await?;
        }
        Subcommand::Upgrade => {
            let latest = factory.latest_version().await?;
            let customization = r#"
            customization:
              systemExtensions:
                officialExtensions:
                  - siderolabs/iscsi-tools
                  - siderolabs/util-linux-tools
            "#;

            let image = factory.get_image(&latest, customization).await?;
            let params = UpgradeParams::default();
            talosctl.upgrade_member(node_ip, &image, &params).await?;

            loop {
                if nodes.is_ready(&node_name).await {
                    info!("node ready");
                    break;
                } else {
                    info!("node not ready");
                    let timeout = Duration::from_secs(1);
                    sleep(timeout).await;
                }
            }
        }
    }

    Ok(())
}

trait NodeApiExt {
    async fn is_ready(&self, name: &str) -> bool;
}

impl NodeApiExt for Api<Node> {
    async fn is_ready(&self, name: &str) -> bool {
        self.get_status(name)
            .await
            .map(|node| {
                node.status
                    .and_then(|node| node.conditions)
                    .unwrap_or_default()
                    .iter()
                    .find(|cond| cond.type_ == "Ready" && cond.status == "True")
                    .is_some()
            })
            .unwrap_or_default()
    }
}

#[instrument]
async fn drain_node(name: &str) -> Result<()> {
    // TODO: find some way to pipe stderr of stdout to tracing with nice filters/formatting
    let output = Command::new("kubectl")
        .arg("drain")
        .arg(name)
        .arg("--ignore-daemonsets")
        .arg("--delete-emptydir-data")
        .arg("--timeout=5m")
        .spawn()?
        .wait_with_output()
        .await?;

    if !output.status.success() {
        anyhow::bail!("failed to drain node");
    }

    Ok(())
}
