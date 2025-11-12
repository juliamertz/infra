use std::time::Duration;

use anyhow::{Context, Result};
use clap::Parser;

mod cluster;
mod cnpg;
mod ext;
mod prompt;
mod talos;

use k8s_openapi_ext::corev1::{Node, Pod};
use kube::api::ListParams;
use kube::{Api, ResourceExt};
use talos::TalosFactory;
use tokio::{process::Command, time::sleep};
use tracing::{Level, info, instrument};

use crate::cnpg::Cluster;
use crate::talos::{TalosCtl, UpgradeParams};

#[derive(Parser)]
struct Opts {
    #[arg(long, short)]
    node: String,

    #[command(subcommand)]
    command: Subcommand,
}

#[derive(Debug, clap::Subcommand)]
enum Subcommand {
    /// Switchover all primary CNPG nodes
    KickDbs,
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
    let nodes = Api::<Node>::all(kube.clone());
    let pods = Api::<Pod>::all(kube.clone());

    let factory = TalosFactory::default();
    let talosctl = TalosCtl::try_new().await?;

    let member = talosctl.member(&opts.node).context("node not found")?;
    let node_name = &member.spec.hostname;
    let node_ip = member
        .external_ip()
        .context("cannot find external ip for member")?;

    match opts.command {
        Subcommand::KickDbs => {
            let field_selector = format!("spec.nodeName={node_name}");
            let label_selector = "cnpg.io/podRole=instance,cnpg.io/instanceRole=primary";
            let list_params = ListParams {
                field_selector: Some(field_selector),
                label_selector: Some(label_selector.into()),
                ..Default::default()
            };

            let primaries = pods.list(&list_params).await?.items;
            // dbg!(&primaries, primaries.len());

            for primary in primaries {
                let Some(cluster_name) = primary
                    .metadata
                    .labels
                    .as_ref()
                    .and_then(|labels| labels.get("cnpg.io/cluster"))
                else {
                    tracing::error!("cnpg pod is missing cluster label");
                    continue;
                };

                dbg!(&cluster_name);
                let clusters = Api::<Cluster>::namespaced(
                    kube.clone(),
                    &primary.namespace().unwrap_or_else(|| "default".to_string()),
                );
                let cluster = clusters.get(&cluster_name).await?;
                dbg!(cluster);
            }
        }
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
                    nodes.uncordon(&node_name).await?;
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
