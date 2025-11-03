use anyhow::Result;
use k8s_openapi_ext::corev1::Node;
use kube::api::{Api, ListParams};
use kube::client::Client;

pub struct Cluster {
    client: Client,
}

impl Cluster {
    pub async fn try_new() -> Result<Self> {
        let client = Client::try_default().await?;
        Ok(Self { client })
    }

    pub async fn list_nodes(&self) -> Result<Vec<Node>> {
        let client = self.client.clone();
        let api = Api::<Node>::all(client);

        let list_params = ListParams::default();
        let list = api.list(&list_params).await?;

        Ok(list.items)
    }
}
