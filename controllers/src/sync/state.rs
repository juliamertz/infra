use std::str::FromStr;

use gix::ObjectId;
use k8s_openapi_ext::ResourceBuilder;
use k8s_openapi_ext::{ConfigMapExt, corev1::ConfigMap};
use kube::Client;
use kube::api::{Api, DynamicObject, Patch, PatchParams};
use tracing::instrument;

use super::{Error, Result};

pub struct State {
    configmaps: Api<ConfigMap>,
}

impl State {
    const CONFIGMAP_NAME: &str = "sync-controller-state";
    const REV_ANNOTATION: &str = "sync-controller.juliamertz.dev/rev";

    pub fn new(client: Client) -> Self {
        Self {
            configmaps: Api::default_namespaced(client),
        }
    }

    #[instrument(skip(self), err(Debug))]
    pub async fn get(&self) -> Result<Option<(ObjectId, Vec<DynamicObject>)>> {
        match self.configmaps.get(Self::CONFIGMAP_NAME).await {
            Ok(configmap) => {
                let annotations = configmap.metadata.annotations.unwrap_or_default();
                let id = ObjectId::from_str(
                    annotations
                        .get(Self::REV_ANNOTATION)
                        .expect("rev annotation"),
                )
                .unwrap();
                let Some(data) = configmap
                    .data
                    .unwrap_or_default()
                    .get("state")
                    .map(|json| serde_json::from_str(json.as_str()))
                    .transpose()?
                else {
                    return Ok(None);
                };
                Ok(Some((id, data)))
            }
            Err(kube::Error::Api(err)) if err.is_not_found() => Ok(None),
            Err(err) => Err(Error::Kube(err)),
        }
    }

    #[instrument(skip(self), err(Debug))]
    pub async fn set(&self, rev: &ObjectId, state: &[DynamicObject]) -> Result<()> {
        let patch = ConfigMap::new(Self::CONFIGMAP_NAME)
            .data([("state", serde_json::to_string(state)?)])
            .annotations([(Self::REV_ANNOTATION, rev.to_string())]);

        let patch_params = PatchParams::apply("sync-controller");
        self.configmaps
            .patch(Self::CONFIGMAP_NAME, &patch_params, &Patch::Apply(patch))
            .await?;

        Ok(())
    }
}
