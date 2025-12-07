use std::sync::Arc;

use chrono::{DateTime, Utc};
use k8s_openapi::api::core::v1::{Node, Pod};
use kube::api::{ObjectMeta, Patch, PatchParams};
use kube::{Api, Client, CustomResource, ResourceExt};
use kubus::{Context, Operator, kubus};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

const ANNOTATION_HOSTNAME: &str = "dns.juliamertz.dev/hostname";
const ANNOTATION_TTL: &str = "dns.juliamertz.dev/ttl";
const ANNOTATION_RETAIN: &str = "dns.juliamertz.dev/retain";
const ANNOTATION_DELETE_AFTER: &str = "dns.juliamertz.dev/delete-after";
const ANNOTATION_MARKED_FOR_DELETION: &str = "dns.juliamertz.dev/marked-for-deletion-at";

const DEFAULT_TTL: i64 = 300;
const DEFAULT_DELETE_DELAY: &str = "24h";

#[derive(Debug, thiserror::Error)]
enum Error {
    #[error("failed to fetch node '{node_name}': {source}")]
    NodeFetch {
        node_name: String,
        source: kube::Error,
    },
    #[error("failed to fetch DNSEndpoint '{name}' in namespace '{namespace}': {source}")]
    EndpointFetch {
        name: String,
        namespace: String,
        source: kube::Error,
    },
    #[error("failed to create/update DNSEndpoint '{name}' in namespace '{namespace}': {source}")]
    EndpointPatch {
        name: String,
        namespace: String,
        source: kube::Error,
    },
    #[error("failed to delete DNSEndpoint '{name}' in namespace '{namespace}': {source}")]
    EndpointDelete {
        name: String,
        namespace: String,
        source: kube::Error,
    },
    #[error("failed to mark DNSEndpoint '{name}' for deletion: {source}")]
    EndpointMarkForDeletion { name: String, source: kube::Error },

    // Configuration/state errors (typically permanent)
    #[error("node '{node_name}' has no ExternalIP address configured")]
    NodeMissingExternalIp { node_name: String },

    // Requeue signals (not actual errors)
    #[error(
        "waiting for deletion delay to expire for endpoint '{name}' (delete after: {delete_after})"
    )]
    AwaitingDeletionDelay { name: String, delete_after: String },
}

#[derive(Debug, Clone)]
struct State {}

pub async fn run() -> Result<(), kubus::Error> {
    let client = Client::try_default().await?;
    let state = State {};

    Operator::builder()
        .with_context((client, state))
        .handler(on_pod_apply)
        .handler(on_pod_delete)
        .run()
        .await
}

#[kubus(
    event = Apply,
    finalizer = "dns.juliamertz.dev/cleanup",
    label_selector = "dns.juliamertz.dev/hostdns=true",
)]
async fn on_pod_apply(pod: Arc<Pod>, ctx: Arc<Context<State>>) -> Result<(), Error> {
    let annotations = pod.metadata.annotations.as_ref();
    let pod_name = pod.name_unchecked();

    let hostname = match annotations.and_then(|a| a.get(ANNOTATION_HOSTNAME)) {
        Some(h) => h.clone(),
        None => return Ok(()),
    };

    let host_network = pod
        .spec
        .as_ref()
        .and_then(|s| s.host_network)
        .unwrap_or(false);

    if !host_network {
        tracing::warn!(
            pod = pod_name,
            "pod has dns annotation but hostNetwork is not enabled, skipping"
        );
        return Ok(());
    }

    let node_name = match pod.spec.as_ref().and_then(|s| s.node_name.as_ref()) {
        Some(n) => n.clone(),
        None => {
            tracing::debug!(pod = pod_name, "pod not yet scheduled");
            return Ok(());
        }
    };

    let phase = pod
        .status
        .as_ref()
        .and_then(|s| s.phase.as_ref())
        .map(|p| p.as_str())
        .unwrap_or("");

    if phase != "Running" {
        tracing::debug!(pod = pod_name, phase, "pod not running yet");
        return Ok(());
    }

    let nodes: Api<Node> = Api::all(ctx.client.clone());
    let node = nodes
        .get(&node_name)
        .await
        .map_err(|source| Error::NodeFetch {
            node_name: node_name.clone(),
            source,
        })?;

    let external_ip = node
        .status
        .as_ref()
        .and_then(|s| s.addresses.as_ref())
        .and_then(|addrs| {
            addrs
                .iter()
                .find(|a| a.type_ == "ExternalIP")
                .map(|a| a.address.clone())
        })
        .ok_or_else(|| Error::NodeMissingExternalIp {
            node_name: node_name.clone(),
        })?;

    let ttl = annotations
        .and_then(|a| a.get(ANNOTATION_TTL))
        .and_then(|t| t.parse::<i64>().ok())
        .unwrap_or(DEFAULT_TTL);

    let retain = annotations
        .and_then(|a| a.get(ANNOTATION_RETAIN))
        .map(|v| v == "true")
        .unwrap_or(false);

    let delete_after = annotations
        .and_then(|a| a.get(ANNOTATION_DELETE_AFTER))
        .cloned()
        .unwrap_or_else(|| DEFAULT_DELETE_DELAY.to_string());

    let namespace = pod.namespace().unwrap_or_else(|| "default".to_string());
    let endpoint_name = format!("node-dns-{}", pod_name);

    let dns_endpoints: Api<DNSEndpoint> = Api::namespaced(ctx.client.clone(), &namespace);

    let mut endpoint_annotations = std::collections::BTreeMap::new();
    if retain {
        endpoint_annotations.insert(ANNOTATION_RETAIN.to_string(), "true".to_string());
    }
    endpoint_annotations.insert(ANNOTATION_DELETE_AFTER.to_string(), delete_after);

    let endpoint = DNSEndpoint {
        metadata: ObjectMeta {
            name: Some(endpoint_name.clone()),
            namespace: Some(namespace.clone()),
            owner_references: Some(pod.owner_references().to_vec()),
            annotations: Some(endpoint_annotations),
            ..Default::default()
        },
        spec: DNSEndpointSpec {
            endpoints: vec![Endpoint {
                dns_name: hostname.clone(),
                record_type: "A".to_string(),
                targets: vec![external_ip.clone()],
                record_ttl: Some(ttl),
            }],
        },
    };

    dns_endpoints
        .patch(
            &endpoint_name,
            &PatchParams::apply("node-dns-controller"),
            &Patch::Apply(&endpoint),
        )
        .await
        .map_err(|source| Error::EndpointPatch {
            name: endpoint_name.clone(),
            namespace: namespace.clone(),
            source,
        })?;

    tracing::info!(
        pod = pod_name,
        hostname,
        ip = external_ip,
        "updated DNS endpoint"
    );

    Ok(())
}

#[kubus(
    event = Delete,
    finalizer = "dns.juliamertz.dev/cleanup",
    label_selector = "dns.juliamertz.dev/hostdns=true",
)]
async fn on_pod_delete(pod: Arc<Pod>, ctx: Arc<Context<State>>) -> Result<(), Error> {
    let annotations = pod.metadata.annotations.as_ref();
    let pod_name = pod.name_unchecked();

    if annotations
        .and_then(|a| a.get(ANNOTATION_HOSTNAME))
        .is_none()
    {
        return Ok(());
    }

    let namespace = pod.namespace().unwrap_or_else(|| "default".to_string());
    let endpoint_name = format!("node-dns-{}", pod_name);

    let dns_endpoints: Api<DNSEndpoint> = Api::namespaced(ctx.client.clone(), &namespace);

    let endpoint = match dns_endpoints.get(&endpoint_name).await {
        Ok(ep) => ep,
        Err(kube::Error::Api(e)) if e.code == 404 => return Ok(()),
        Err(source) => {
            return Err(Error::EndpointFetch {
                name: endpoint_name,
                namespace,
                source,
            });
        }
    };

    let endpoint_annotations = endpoint.metadata.annotations.as_ref();

    let retain = endpoint_annotations
        .and_then(|a| a.get(ANNOTATION_RETAIN))
        .map(|v| v == "true")
        .unwrap_or(false);

    if retain {
        tracing::info!(
            pod = pod_name,
            endpoint = endpoint_name,
            "retaining DNS endpoint (retain=true)"
        );
        return Ok(());
    }

    let delete_after_str = endpoint_annotations
        .and_then(|a| a.get(ANNOTATION_DELETE_AFTER))
        .cloned()
        .unwrap_or_else(|| DEFAULT_DELETE_DELAY.to_string());

    let delete_delay = humantime::parse_duration(&delete_after_str)
        .ok()
        .and_then(|d| chrono::Duration::from_std(d).ok())
        .unwrap_or_else(|| chrono::Duration::hours(24));

    let marked_at = endpoint_annotations
        .and_then(|a| a.get(ANNOTATION_MARKED_FOR_DELETION))
        .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        .map(|dt| dt.with_timezone(&Utc));

    let now = Utc::now();

    match marked_at {
        Some(marked_time) => {
            let delete_at = marked_time + delete_delay;
            if now >= delete_at {
                match dns_endpoints
                    .delete(&endpoint_name, &Default::default())
                    .await
                {
                    Ok(_) => {
                        tracing::info!(
                            pod = pod_name,
                            endpoint = endpoint_name,
                            "deleted DNS endpoint after delay"
                        );
                    }
                    Err(kube::Error::Api(e)) if e.code == 404 => {}
                    Err(source) => {
                        return Err(Error::EndpointDelete {
                            name: endpoint_name,
                            namespace,
                            source,
                        });
                    }
                }
            } else {
                let remaining = delete_at - now;
                tracing::info!(
                    pod = pod_name,
                    endpoint = endpoint_name,
                    remaining_seconds = remaining.num_seconds(),
                    "DNS endpoint deletion delayed"
                );
            }
        }
        None => {
            let patch = serde_json::json!({
                "metadata": {
                    "annotations": {
                        ANNOTATION_MARKED_FOR_DELETION: now.to_rfc3339()
                    }
                }
            });

            dns_endpoints
                .patch(
                    &endpoint_name,
                    &PatchParams::default(),
                    &Patch::Merge(&patch),
                )
                .await
                .map_err(|source| Error::EndpointMarkForDeletion {
                    name: endpoint_name.clone(),
                    source,
                })?;

            tracing::info!(
                pod = pod_name,
                endpoint = endpoint_name,
                delete_after = delete_after_str,
                "marked DNS endpoint for delayed deletion"
            );

            return Err(Error::AwaitingDeletionDelay {
                name: endpoint_name,
                delete_after: delete_after_str,
            });
        }
    }

    Ok(())
}

#[derive(Clone, Debug, Deserialize, Serialize, CustomResource, JsonSchema)]
#[kube(
    group = "externaldns.k8s.io",
    version = "v1alpha1",
    kind = "DNSEndpoint",
    namespaced
)]
pub struct DNSEndpointSpec {
    pub endpoints: Vec<Endpoint>,
}

#[derive(Clone, Debug, Deserialize, Serialize, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct Endpoint {
    pub dns_name: String,
    pub record_type: String,
    pub targets: Vec<String>,
    #[serde(rename = "recordTTL", skip_serializing_if = "Option::is_none")]
    pub record_ttl: Option<i64>,
}
