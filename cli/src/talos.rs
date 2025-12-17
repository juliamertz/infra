use std::{cmp::Ordering, net::Ipv4Addr, process::Stdio};

use anyhow::{Context, Result};
use reqwest::{Body, Client};
use serde::{Deserialize, de::DeserializeOwned};
use serde_json::Deserializer;
use tokio::process::Command;
use tracing::instrument;
use version_compare::Version;

use crate::ext::CommandExt;

#[derive(Default)]
pub struct TalosFactory {
    pub client: Client,
}

#[derive(Deserialize)]
struct SchematicsResponse {
    id: String,
}

#[derive(Debug)]
pub struct Image {
    pub tag: String,
}

impl TalosFactory {
    pub async fn list_versions(&self) -> Result<Vec<String>> {
        Ok(self
            .client
            .get("https://factory.talos.dev/versions")
            .send()
            .await?
            .json()
            .await?)
    }

    pub async fn latest_version(&self) -> Result<String> {
        let versions = self.list_versions().await?;
        let mut parsed: Vec<_> = versions
            .iter()
            .filter(|v| !(v.contains("alpha") || v.contains("beta")))
            .filter_map(|value| Version::from(&value))
            .collect();

        parsed.sort_by(|a, b| a.compare(b).ord().unwrap_or(Ordering::Equal));
        Ok(parsed.pop().expect("atleast one version").to_string())
    }

    pub async fn get_image(
        &self,
        version: impl AsRef<str>,
        customization: impl Into<Body>,
    ) -> Result<Image> {
        let schematic: SchematicsResponse = self
            .client
            .post("https://factory.talos.dev/schematics")
            .header("content-type", "application/yaml")
            .body(customization)
            .send()
            .await?
            .json()
            .await?;

        let id = schematic.id;
        let version = version.as_ref();
        let tag = format!("factory.talos.dev/hcloud-installer/{id}:{version}");

        Ok(Image { tag })
    }
}

fn parse_json_object_stream<T: DeserializeOwned>(text: &str) -> Result<Vec<T>, serde_json::Error> {
    let deserializer = Deserializer::from_str(text);
    let items: Vec<T> = deserializer
        .into_iter::<T>()
        .collect::<Result<Vec<_>, _>>()?;

    Ok(items)
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberMeta {
    pub id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberSpec {
    pub addresses: Vec<Ipv4Addr>,
    pub hostname: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NodeItem<Meta, Spec> {
    pub metadata: Meta,
    pub spec: Spec,
}

pub type Member = NodeItem<MemberMeta, MemberSpec>;

impl Member {
    // pub fn version(&self) -> Result<Version<'_>> {
    //     let os = &self.spec.operating_system;
    //     let (_, rhs) = os.split_once(" ").context("invalid talos os string")?;
    //     rhs.strip_prefix("(")
    //         .and_then(|v| v.strip_suffix(")"))
    //         .and_then(Version::from)
    //         .context("invalid talos version")
    // }

    pub fn external_ip(&self) -> Option<&Ipv4Addr> {
        self.spec
            .addresses
            .iter()
            .rev()
            .find(|addr| !addr.is_private())
    }
}

pub mod kubeconfig {
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "camelCase")]
    pub struct Config {
        pub api_version: String,
        pub kind: String,
        pub clusters: Vec<NamedCluster>,
        pub contexts: Vec<NamedContext>,
        #[serde(rename = "current-context")]
        pub current_context: String,
        pub users: Vec<NamedUser>,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "kebab-case")]
    pub struct NamedCluster {
        pub name: String,
        pub cluster: Cluster,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "kebab-case")]
    pub struct Cluster {
        pub certificate_authority_data: String,
        pub server: String,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "kebab-case")]
    pub struct NamedContext {
        pub name: String,
        pub context: Context,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "kebab-case")]
    pub struct Context {
        pub cluster: String,
        pub namespace: String,
        pub user: String,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(rename_all = "kebab-case")]
    pub struct NamedUser {
        pub name: String,
        pub user: User,
    }

    #[derive(Debug, Serialize, Deserialize)]
    #[serde(untagged)]
    pub enum User {
        Token {
            token: String,
        },
        ClientKey {
            #[serde(rename = "client-certificate-data")]
            client_certificate_data: String,
            #[serde(rename = "client-key-data")]
            client_key_data: String,
        },
    }

    impl Config {
        pub fn set_user(&mut self, user: NamedUser) {
            let Some(context) = self.contexts.first_mut() else {
                return;
            };

            context.name = user.name.clone();
            context.context.user = user.name.clone();

            self.users = vec![user];
            self.current_context = context.name.clone();
        }

        pub fn set_namespace(&mut self, namespace: impl ToString) {
            self.contexts
                .iter_mut()
                .for_each(|ctx| ctx.context.namespace = namespace.to_string());
        }
    }

    impl User {
        pub fn token(token: impl ToString) -> Self {
            let token = token.to_string();
            Self::Token { token }
        }
    }
}

#[derive(Debug)]
pub struct TalosCtl {
    pub members: Vec<Member>,
}

#[derive(Debug)]
pub struct UpgradeParams {
    /// Preserve data on disk (set to `true` when using longhorn storage)
    preserve: bool,
}

impl Default for UpgradeParams {
    fn default() -> Self {
        Self { preserve: true }
    }
}

impl TalosCtl {
    pub async fn try_new() -> Result<Self> {
        let mut client = Self { members: vec![] };
        client.members = client.list_members().await?;
        Ok(client)
    }

    pub async fn list_members(&self) -> Result<Vec<Member>> {
        let mut cmd = Command::new("talosctl");
        let output = cmd
            .stdout(Stdio::piped())
            .arg("get")
            .arg("members")
            .arg("--output")
            .arg("json")
            .spawn()?
            .wait_with_output()
            .await?;

        if !output.status.success() {
            anyhow::bail!("failed to run 'talosctl get members'");
        }

        let stdout = str::from_utf8(output.stdout.as_slice())?;
        Ok(parse_json_object_stream(stdout)?)
    }

    pub fn member(&self, name: &str) -> Option<&Member> {
        self.members
            .iter()
            .find(|member| member.metadata.id == name)
    }

    #[allow(unused)]
    #[instrument(skip(self))]
    pub async fn get_schematic(&self, member: &Member) -> Result<serde_yaml::Value> {
        let mut cmd = Command::new("talosctl");
        let node_ip = member
            .external_ip()
            .context("cannot find external ip for member")?;

        let output = cmd
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .arg("get")
            .arg("extensions")
            .arg("--output")
            .arg("json")
            .arg("--nodes")
            .arg(node_ip.to_string())
            .spawn()?
            .wait_with_output()
            .await?;

        if !output.status.success() {
            anyhow::bail!("failed to run 'talosctl get extensions'");
        }

        let stdout = str::from_utf8(output.stdout.as_slice())?;
        let items: serde_yaml::Value =
            parse_json_object_stream::<NodeItem<serde_json::Value, serde_json::Value>>(stdout)?
                .iter()
                .find(|item| item.spec["metadata"]["name"] == "schematic")
                .and_then(|item| {
                    item.spec["metadata"]["extraInfo"]
                        .clone()
                        .as_str()
                        .and_then(|v| serde_yaml::from_str(v).ok())
                })
                .context("unable to find schematic for node")?;

        Ok(items)
    }

    pub async fn upgrade_member(
        &self,
        ip: &Ipv4Addr,
        image: &Image,
        params: &UpgradeParams,
    ) -> Result<()> {
        let mut cmd = Command::new("talosctl");

        let output = cmd
            .stdout(Stdio::piped())
            .arg("upgrade")
            .arg("--nodes")
            .arg(&ip.to_string())
            .arg("--image")
            .arg(&image.tag)
            .bool_flag("--preserve", params.preserve)
            .spawn()?
            .wait_with_output()
            .await?;

        if !output.status.success() {
            let stderr = str::from_utf8(&output.stderr)?;
            anyhow::bail!("failed to run 'talosctl upgrade: {stderr}'");
        }

        Ok(())
    }

    #[instrument(skip(self))]
    pub async fn get_kubeconfig(&self, member: &Member) -> Result<kubeconfig::Config> {
        let mut cmd = Command::new("talosctl");
        let node_ip = member
            .external_ip()
            .context("cannot find external ip for member")?;

        let output = cmd
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .arg("--nodes")
            .arg(node_ip.to_string())
            .arg("kubeconfig")
            .arg("--merge=false")
            .arg("-")
            .spawn()?
            .wait_with_output()
            .await?;

        if !output.status.success() {
            anyhow::bail!("failed to run 'talosctl get extensions'");
        }

        Ok(serde_yaml::from_slice(output.stdout.as_slice())?)
    }
}
