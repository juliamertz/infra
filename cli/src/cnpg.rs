use anyhow::{Context, Result, bail};
use chrono::Utc;
use k8s_openapi_ext::{corev1::Pod, metav1::Condition};
use kube::{
    Api, Client, CustomResource, ResourceExt,
    api::{ListParams, Patch, PatchParams},
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

#[derive(Debug)]
pub struct InstancePlacement {
    pub node_name: String,
    pub is_primary: bool,
    pub instance: u32,
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
                .any(|cond| cond.reason == "ClusterIsReady" && cond.status == "True")
    }

    pub async fn get_layout(&self, client: Client) -> Result<Vec<InstancePlacement>> {
        let name = self.name_any();
        let namespace = self.namespace().unwrap();

        let pods = Api::<Pod>::namespaced(client, &namespace);
        let label_selector = format!("cnpg.io/cluster={name}");
        let list_params = ListParams::default().labels(&label_selector);

        pods.list(&list_params)
            .await?
            .into_iter()
            .map(|pod| {
                let spec = pod.spec.as_ref().unwrap();
                Ok::<_, anyhow::Error>(InstancePlacement {
                    node_name: spec.node_name.clone().unwrap_or_default(),
                    is_primary: pod
                        .labels()
                        .get("cnpg.io/instanceRole")
                        .context("expected 'cnpg.io/instanceRole' label")?
                        == "primary",
                    instance: pod
                        .annotations()
                        .get("cnpg.io/nodeSerial")
                        .context("expected 'cnpg.io/nodeSerial' annotation")?
                        .parse()
                        .context("nodeSerial is not a valid integer")?,
                })
            })
            .collect()
    }

    #[instrument(skip(self, client), fields(name = self.name_any(), namespace = self.namespace()), err(Debug))]
    async fn switchover(&self, client: Client, instance: u32) -> Result<()> {
        let name = self.name_any();
        let namespace = self.namespace().unwrap_or_else(|| "default".into());
        let target = format!("{name}-{instance}");

        tracing::info!("starting switchover");

        if let Some(target_primary) = &self
            .status
            .as_ref()
            .and_then(|status| status.target_primary.as_ref())
            && target_primary.ends_with(&instance.to_string())
        {
            info!("already the primary node in the cluster");
            return Ok(());
        }

        let pods = Api::<Pod>::namespaced(client.clone(), &namespace);
        if pods.get(&target).await.is_err() {
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
        let layout = self.get_layout(client.clone()).await?;

        let primary = layout
            .iter()
            .find(|instance| instance.is_primary)
            .context("no primary instance found for cluster")?;
        let mut victims = layout
            .iter()
            .filter(|instance| !instance.is_primary && instance.node_name != primary.node_name);

        let victim = victims
            .next()
            .context("unable to switchover, no victims found")?;

        self.switchover(client, victim.instance).await
    }
}
