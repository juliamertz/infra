use std::time::Duration;

use anyhow::Result;
use k8s_openapi_ext::corev1::Pod;
use kube::ResourceExt;
use kube::{Api, api::ListParams};
use tokio::task::JoinSet;
use tokio::time::sleep;
use tracing::info;

use crate::Context;
use crate::cnpg::Cluster;
use crate::talos::Member;

pub async fn handle(ctx: Context, member: &Member) -> Result<()> {
    let node_name = member.hostname();
    let field_selector = format!("spec.nodeName={node_name}");
    let label_selector = "cnpg.io/podRole=instance,cnpg.io/instanceRole=primary";
    let list_params = ListParams {
        field_selector: Some(field_selector),
        label_selector: Some(label_selector.into()),
        ..Default::default()
    };

    let pods = Api::<Pod>::all(ctx.kube.clone());
    let primaries = pods.list(&list_params).await?.items;

    let mut set = JoinSet::new();

    for primary in primaries {
        set.spawn(do_switchover(ctx.clone(), primary));
    }

    set.join_all()
        .await
        .into_iter()
        .collect::<Result<Vec<_>>>()
        .map(|_| ())
}

async fn do_switchover(ctx: Context, primary: Pod) -> Result<()> {
    let Some(cluster_name) = primary
        .metadata
        .labels
        .as_ref()
        .and_then(|labels| labels.get("cnpg.io/cluster"))
    else {
        anyhow::bail!("cnpg pod is missing cluster label");
    };

    tracing::info!("found primary {}", primary.name_any());

    let namespace = primary.namespace().unwrap_or_else(|| "default".to_string());
    let clusters = Api::<Cluster>::namespaced(ctx.kube.clone(), &namespace);
    let cluster = clusters.get(cluster_name).await?;

    cluster.switchover_any(ctx.kube.clone()).await?;

    loop {
        let cluster = clusters.get(cluster_name).await?;
        if cluster.is_healthy() {
            info!({ cluster_name, namespace }, "cluster ready");
            break Ok(());
        } else {
            info!({ cluster_name, namespace }, "cluster not ready");
            let timeout = Duration::from_secs(1);
            sleep(timeout).await;
        }
    }
}
