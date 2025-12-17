use anyhow::{Context, Result, bail};
use chrono::Utc;
use k8s_openapi_ext::{corev1::Pod, metav1::Condition};
use kube::{
    Api, Client, CustomResource, ResourceExt,
    api::{Patch, PatchParams},
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::json;
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
    pub conditions: Option<Vec<Condition>>,
    #[serde(rename = "healthyPVC")]
    pub healthy_pvc: Option<Vec<String>>,
    pub instance_names: Option<Vec<String>>,
    pub ready_instances: Option<u32>,
}

impl Cluster {
    const PHASE_SWITCHOVER: &str = "Switchover in progress";

    pub fn is_healthy(&self) -> bool {
        let Some(ref status) = self.status else {
            return false;
        };

        status.current_primary.is_some()
            && status.target_primary == status.current_primary
            && status.ready_instances.unwrap_or_default() == self.spec.instances
            && status
                .conditions
                .clone()
                .unwrap_or_default()
                .iter()
                .find(|ref cond| cond.reason == "ClusterIsReady" && cond.status == "True")
                .is_some()
    }

    #[instrument(skip(self, client), fields(name = self.name_any(), namespace = self.namespace()), err(Debug))]
    async fn switchover(&self, client: Client, target: &str) -> Result<()> {
        let name = self.name_any();
        let namespace = self.namespace().unwrap_or_else(|| "default".into());

        tracing::info!("starting switchover");

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

        let now = Utc::now().to_rfc3339();
        let current_primary = self
            .status
            .as_ref()
            .and_then(|status| status.current_primary.to_owned());

        let patch = json!({
            "status": {
                "targetPrimary": target,
                "targetPrimaryTimestamp": now,
                "phase": Self::PHASE_SWITCHOVER,
                "phaseReason": format!("Switching over to {target}"),
                "currentPrimary": current_primary,
            }
        });

        let client = client.clone();
        let clusters = Api::<Cluster>::namespaced(client, &namespace);
        clusters
            .patch_status(&name, &PatchParams::apply("infra"), &Patch::Merge(patch))
            .await?;

        Ok(())
    }

    #[instrument(skip(self, client), fields(namespace = self.namespace()), err(Debug))]
    pub async fn switchover_any(&self, client: Client) -> Result<()> {
        let status = self.status.clone().unwrap_or_default();
        let mut victims = status
            .instance_names
            .unwrap_or_default()
            .into_iter()
            .filter(|name| name != &status.current_primary.clone().unwrap_or_default())
            .collect::<Vec<_>>();

        let victim = victims
            .pop()
            .context("unable to switchover, no victims found")?;

        self.switchover(client, &victim).await
    }
}
