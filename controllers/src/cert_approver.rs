use ipnet::IpNet;
use k8s_openapi::api::certificates::v1::{
    CertificateSigningRequest, CertificateSigningRequestCondition, CertificateSigningRequestStatus,
};
use k8s_openapi::api::core::v1::Node;
use kube::api::{Api, ListParams, Patch, PatchParams};
use kube::{Client, ResourceExt};
use std::str::FromStr;
use tokio::time::{Duration, sleep};
use tracing::{debug, error, info, warn};

pub struct Config {
    pub internal_ip_range: String,
}

pub async fn run(config: Config) -> Result<(), Box<dyn std::error::Error>> {
    let ip_net = IpNet::from_str(&config.internal_ip_range).map_err(|e| {
        format!(
            "Invalid INTERNAL_IP_RANGE '{}': {}",
            config.internal_ip_range, e
        )
    })?;

    info!(
        range = config.internal_ip_range,
        "cert-approver started with IP range"
    );

    let client = Client::try_default().await?;
    let csrs: Api<CertificateSigningRequest> = Api::all(client.clone());
    let nodes: Api<Node> = Api::all(client.clone());

    loop {
        let list_params = ListParams::default();
        let csr_list = match csrs.list(&list_params).await {
            Ok(list) => list,
            Err(e) => {
                error!(error = %e, "failed to list CSRs");
                sleep(Duration::from_secs(10)).await;
                continue;
            }
        };

        for csr in csr_list {
            if csr
                .status
                .as_ref()
                .and_then(|s| s.conditions.as_ref())
                .is_some()
            {
                continue;
            }

            let csr_name = csr.name_unchecked();
            let username = csr.spec.username.as_deref().unwrap_or("");

            if !username.starts_with("system:node:") {
                continue;
            }

            let node_name = match username.strip_prefix("system:node:") {
                Some(name) => name,
                None => continue,
            };

            let node = match nodes.get(node_name).await {
                Ok(node) => node,
                Err(e) => {
                    debug!(
                        csr = csr_name,
                        node = node_name,
                        error = %e,
                        "node not found, skipping CSR"
                    );
                    continue;
                }
            };

            let internal_ip = node
                .status
                .as_ref()
                .and_then(|s| s.addresses.as_ref())
                .and_then(|addrs| {
                    addrs
                        .iter()
                        .find(|a| a.type_ == "InternalIP")
                        .map(|a| a.address.clone())
                });

            let (should_approve, ip_str) = match internal_ip {
                Some(ref ip_str) => match ip_str.parse::<std::net::IpAddr>() {
                    Ok(ip) => {
                        let in_range = ip_net.contains(&ip);
                        if !in_range {
                            debug!(
                                csr = csr_name,
                                node = node_name,
                                ip = ip_str,
                                range = config.internal_ip_range,
                                "node IP not in allowed range"
                            );
                        }
                        (in_range, Some(ip_str.clone()))
                    }
                    Err(e) => {
                        warn!(
                            csr = csr_name,
                            node = node_name,
                            ip = ip_str,
                            error = %e,
                            "failed to parse node IP"
                        );
                        (false, Some(ip_str.clone()))
                    }
                },
                None => {
                    debug!(
                        csr = csr_name,
                        node = node_name,
                        "node has no InternalIP, skipping"
                    );
                    (false, None)
                }
            };

            if should_approve {
                let patch = CertificateSigningRequest {
                    status: Some(CertificateSigningRequestStatus {
                        conditions: Some(vec![CertificateSigningRequestCondition {
                            message: Some(format!(
                                "Auto-approved by cert-approver: node IP in range {}",
                                config.internal_ip_range
                            )),
                            reason: Some("AutoApproved".into()),
                            status: "True".into(),
                            type_: "Approved".into(),
                            ..Default::default()
                        }]),
                        ..Default::default()
                    }),
                    ..Default::default()
                };

                let mut patch_params = PatchParams::apply("infra");
                patch_params.field_manager = Some("cert-approver".to_string());

                match csrs
                    .patch_approval(&csr_name, &patch_params, &Patch::Merge(&patch))
                    .await
                {
                    Ok(_) => {
                        info!(
                            csr = csr_name,
                            node = node_name,
                            ip = ip_str.as_deref().unwrap_or("unknown"),
                            "approved CSR"
                        );
                    }
                    Err(e) => {
                        error!(
                            csr = csr_name,
                            error = %e,
                            "failed to approve CSR"
                        );
                    }
                }
            }
        }

        sleep(Duration::from_secs(5)).await;
    }
}
