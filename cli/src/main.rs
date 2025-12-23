use std::io::Write;
use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use clap::Parser;
use k8s_openapi_ext::authenticationv1::{TokenRequest, TokenRequestSpec};
use k8s_openapi_ext::corev1::{Node, Pod, ServiceAccount};
use kube::api::{ListParams, PostParams};
use kube::{Api, Client as KubeClient, ResourceExt};
use talos::TalosFactory;
use tokio::fs;
use tokio::{process::Command, time::sleep};
use tracing::{Level, info, instrument};

mod cnpg;
mod ext;
mod talos;

use crate::cnpg::Cluster;
use crate::ext::DurationExt;
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
    // ListNodes {
    //     #[arg(long, short, env = "HCLOUD_TOKEN")]
    //     token: String,
    // },
    /// Switchover all primary CNPG nodes
    KickDbs,
    /// Evict all pods and prepare node for upgrade
    Drain,
    /// Reboot and upgrade node
    Upgrade {
        #[arg(long, default_value_t = false)]
        latest: bool,

        #[arg(long, short)]
        version: Option<String>,

        #[arg(long, short)]
        customization_path: Option<PathBuf>,
    },
    GetKubeconfig {
        #[arg(long, short)]
        service_account: String,

        #[arg(long, short)]
        namespace: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let opts = Opts::parse();
    let kube = KubeClient::try_default().await?;
    let nodes = Api::<Node>::all(kube.clone());

    let factory = TalosFactory::default();
    let talosctl = TalosCtl::try_new().await?;

    let member = talosctl.member(&opts.node).context("node not found")?;
    let node_name = &member.spec.hostname;
    let node_ip = member
        .external_ip()
        .context("cannot find external ip for member")?;

    match opts.command {
        Subcommand::KickDbs => {
            switchover_cnpg_primaries(kube, node_name).await?;
        }
        Subcommand::Drain => {
            nodes.cordon(node_name).await?;
            drain_node(node_name).await?;
        }
        Subcommand::Upgrade {
            latest,
            version,
            customization_path,
        } => {
            let customization_path =
                customization_path.unwrap_or_else(|| "talos-customization.yaml".into());
            let version = if latest && version.is_some() {
                bail!("'latest' and 'version' arguments are mutually exclusive");
            } else if latest {
                factory.latest_version().await?
            } else if let Some(version) = version {
                version
            } else {
                bail!("specify either the 'version' or 'latest' flag");
            };

            tracing::info!("Upgrading {node_name} ({node_ip}) to version {version}");

            let is_cordoned = nodes
                .get(&node_name)
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
            let image = factory.get_image(&version, customization).await?;
            let params = UpgradeParams::default();
            talosctl.upgrade_member(node_ip, &image, &params).await?;

            loop {
                if nodes.is_ready(&node_name).await {
                    info!("node ready");
                    if is_cordoned {
                        nodes.uncordon(&node_name).await?;
                    };
                    break;
                } else {
                    info!("node not ready");
                    let timeout = Duration::from_secs(1);
                    sleep(timeout).await;
                }
            }
        }

        Subcommand::GetKubeconfig {
            service_account: service_account_name,
            namespace,
        } => {
            use crate::talos::kubeconfig::*;

            let mut kubeconfig = talosctl.get_kubeconfig(&member).await?;

            let service_accounts = Api::<ServiceAccount>::namespaced(kube.clone(), &namespace);

            let expiration: Duration = DurationExt::from_weeks(16);
            let token_req = service_accounts
                .create_token_request(
                    &service_account_name,
                    &PostParams::default(),
                    &TokenRequest {
                        spec: TokenRequestSpec {
                            audiences: vec![],
                            bound_object_ref: None,
                            expiration_seconds: Some(expiration.as_secs() as i64),
                        },
                        ..Default::default()
                    },
                )
                .await?;

            let token = token_req
                .status
                .context("token request has no status")?
                .token;

            let cluster = kubeconfig
                .clusters
                .first()
                .expect("atleast one cluster in kubeconfig");
            let cluster_name = cluster.name.clone();

            kubeconfig.set_user(NamedUser {
                name: format!("{service_account_name}@{cluster_name}"),
                user: User::token(token),
            });
            kubeconfig.set_namespace(&namespace);

            let kubeconfig_yaml =
                serde_yaml::to_string(&kubeconfig).expect("Failed to serialize to YAML");

            std::io::stdout()
                .write_all(kubeconfig_yaml.as_str().as_bytes())
                .unwrap();
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

/// Find all CNPG pods for a given node where role=primary then switchover to a different instance
async fn switchover_cnpg_primaries(client: KubeClient, node_name: &str) -> Result<()> {
    let field_selector = format!("spec.nodeName={node_name}");
    let label_selector = "cnpg.io/podRole=instance,cnpg.io/instanceRole=primary";
    let list_params = ListParams {
        field_selector: Some(field_selector),
        label_selector: Some(label_selector.into()),
        ..Default::default()
    };

    let pods = Api::<Pod>::all(client.clone());
    let primaries = pods.list(&list_params).await?.items;

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

        tracing::info!("found primary {}", primary.name_any());

        let clusters = Api::<Cluster>::namespaced(
            client.clone(),
            &primary.namespace().unwrap_or_else(|| "default".to_string()),
        );
        let cluster = clusters.get(&cluster_name).await?;

        cluster.switchover_any(client.clone()).await?;

        loop {
            let cluster = clusters.get(&cluster_name).await?;
            if cluster.is_healthy() {
                info!("cluster ready");
                break;
            } else {
                info!("cluster not ready");
                let timeout = Duration::from_secs(1);
                sleep(timeout).await;
            }
        }
    }

    Ok(())
}
