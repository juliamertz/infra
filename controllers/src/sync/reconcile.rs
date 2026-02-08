use std::ops::{Deref, DerefMut};

use kube::api::{
    Api, ApiResource, DeleteParams, DynamicObject, GroupVersionKind, Patch, PatchParams,
    ResourceExt,
};
use kube::core::Status;
use kube::core::response::StatusSummary;
use kube::discovery::{Discovery, Scope};
use tracing::error;

fn namespace_or_default(object: &DynamicObject) -> &str {
    object
        .metadata
        .namespace
        .as_ref()
        .map(String::as_str)
        .unwrap_or("default")
}

fn fullname(object: &DynamicObject) -> String {
    format!(
        "{}/{}",
        namespace_or_default(object),
        object.name_unchecked()
    )
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("kube error: {0}")]
    Kube(#[from] kube::Error),
    #[error("kubernetes failure status: {0:?}")]
    Status(kube::core::response::Status),
    #[error("failed to extract type meta: {}", fullname(.0))]
    MissingTypeMeta(DynamicObject),
    #[error("unknown resource type: {}/{} {}", .0.group, .0.version, .0.kind)]
    UnknownApiGroup(GroupVersionKind),
}

type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug, Clone)]
pub struct Resource(pub DynamicObject);

impl Deref for Resource {
    type Target = DynamicObject;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl DerefMut for Resource {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}

impl PartialEq for Resource {
    fn eq(&self, other: &Self) -> bool {
        self.metadata.name == other.metadata.name
            && self.metadata.namespace == other.metadata.namespace
    }
}

impl From<DynamicObject> for Resource {
    fn from(value: DynamicObject) -> Self {
        Self(value)
    }
}

#[derive(Debug)]
pub enum Action {
    Create(Resource),
    Delete(Resource),
}

impl Action {
    fn resource(&self) -> &Resource {
        match self {
            Self::Create(val) => val,
            Self::Delete(val) => val,
        }
    }

    async fn run(&self, client: kube::Client, discovery: &kube::Discovery) -> Result<()> {
        let resource = self.resource();
        let type_meta = resource
            .types
            .as_ref()
            .ok_or_else(|| Error::MissingTypeMeta(resource.deref().clone()))?;

        let (group, version) = match type_meta.api_version.split_once('/') {
            Some((g, v)) => (g, v),
            None => ("", type_meta.api_version.as_str()),
        };

        let gvk = GroupVersionKind::gvk(group, version, &type_meta.kind);
        let api_resource = ApiResource::from_gvk(&gvk);
        let is_cluster_scoped = discovery
            .resolve_gvk(&gvk)
            .map(|(_, caps)| caps.scope == Scope::Cluster)
            .ok_or_else(|| Error::UnknownApiGroup(gvk))?;

        let name = resource.name_unchecked();

        let api: Api<DynamicObject> = if is_cluster_scoped {
            Api::all_with(client.clone(), &api_resource)
        } else {
            let namespace = namespace_or_default(resource.deref());
            Api::namespaced_with(client.clone(), namespace, &api_resource)
        };

        match self {
            Action::Create(_) => {
                let obj = resource.deref();

                tracing::debug!({ name = fullname(obj) }, "applying");

                api.patch(
                    &name,
                    &PatchParams::apply("sync-controller").force(),
                    &Patch::Apply(obj),
                )
                .await?;
            }
            Action::Delete(_) => {
                let obj = resource.deref();
                let params = DeleteParams::default();

                tracing::debug!({ name = fullname(obj) }, "deleting");

                let result = api.delete(&name, &params).await?;

                if let Some(
                    status @ Status {
                        status: Some(StatusSummary::Failure),
                        ..
                    },
                ) = result.right()
                {
                    tracing::error!(
                        { e = &Error::Status(status) as &dyn std::error::Error },
                        "error deleting resource"
                    );
                }
            }
        };

        Ok(())
    }
}

#[derive(Debug)]
pub struct Plan {
    pub actions: Vec<Action>,
}

impl Plan {
    pub fn new<R: Into<Resource>>(head: Vec<R>, next: Vec<R>) -> Self {
        let next = next.into_iter().map(Into::into).collect::<Vec<_>>();
        let to_delete: Vec<_> = head
            .into_iter()
            .map(Into::into)
            .filter(|obj| !next.contains(obj))
            .map(Action::Delete)
            .collect();

        let to_create: Vec<_> = next.into_iter().map(Action::Create).collect();

        Self {
            actions: [to_delete, to_create].into_iter().flatten().collect(),
        }
    }

    pub async fn apply(&self, client: kube::Client) -> Result<(), Vec<Error>> {
        let discovery = Discovery::new(client.clone())
            .run()
            .await
            .map_err(|err| vec![Error::Kube(err)])?;

        let mut errors = vec![];
        for action in &self.actions {
            let client = client.clone();
            if let Err(err) = action.run(client, &discovery).await {
                error!(
                    { err = &err as &dyn std::error::Error },
                    "failed to run reconciliation action"
                );
                errors.push(err);
            }
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}
