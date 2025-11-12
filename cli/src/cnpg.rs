use anyhow::{Result, bail};
use chrono::Utc;
use k8s_openapi_ext::corev1::Pod;
use kube::{
    Api, Client, CustomResource, ResourceExt,
    api::{Patch, PatchParams},
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use tracing::{info, instrument};

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[kube(
    group = "postgresql.cnpg.io",
    version = "v1",
    kind = "Cluster",
    namespaced
)]
#[kube(status = "ClusterStatus")]
#[kube(
    printcolumn = r#"{"name": "Ready", "type": "boolean", "jsonPath": ".status.ready"}"#,
    printcolumn = r#"{"name": "Message", "type": "string", "jsonPath": ".status.message"}"#
)]
#[serde(rename_all = "camelCase")]
pub struct ClusterSpec {
    pub instances: u32,
}

#[derive(Deserialize, Serialize, Clone, Debug, Default, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct ClusterStatus {
    pub phase: Option<String>,
    pub phase_reason: Option<String>,
    pub target_primary: Option<String>,
    pub target_primary_timestamp: Option<String>,
    pub current_primary: Option<String>,
}

impl Cluster {
    const PHASE_SWITCHOVER: &str = "Switchover in progress";

    #[instrument(skip(self, client), fields(namespace = self.namespace()))]
    async fn switchover(&self, client: Client, target: &str) -> Result<()> {
        let name = self.name_any();
        let namespace = self.namespace().unwrap_or_else(|| "default".into());

        if let Some(target_primary) = &self
            .status
            .as_ref()
            .and_then(|status| status.target_primary.as_ref())
            && target_primary.as_str() == target
        {
            info!("already the primary node in the cluster");
            return Ok(());
        }

        let pods = Api::<Pod>::namespaced(client.clone(), &namespace);
        if pods.get(target).await.is_err() {
            bail!("new primary node not found in namespace")
        }

        let status = ClusterStatus {
            target_primary: Some(target.to_owned()),
            target_primary_timestamp: Some(Utc::now().to_rfc3339()),
            phase: Some(Self::PHASE_SWITCHOVER.to_owned()),
            phase_reason: Some(format!("Switching over to {target}")),
            current_primary: self
                .status
                .as_ref()
                .and_then(|status| status.current_primary.to_owned()),
        };

        let client = client.clone();
        let clusters = Api::<Cluster>::namespaced(client, &namespace);
        clusters
            .patch_status(&name, &PatchParams::apply("infra"), &Patch::Apply(status))
            .await?;

        Ok(())
    }
}
