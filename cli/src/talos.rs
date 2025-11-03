use std::{
    cmp::Ordering,
    net::{IpAddr, Ipv4Addr},
    process::Stdio,
};

use anyhow::{Context, Result};
use reqwest::{Body, Client};
use serde::{Deserialize, de::DeserializeOwned};
use serde_json::Deserializer;
use tokio::process::Command;
use tracing::instrument;
use version_compare::Version;

use crate::jlib::CommandExt;

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
    pub id: String,
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

        Ok(Image { id, tag })
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
    pub phase: String, // TODO: enum?
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberSpec {
    pub node_id: String,
    pub addresses: Vec<Ipv4Addr>,
    pub hostname: String,
    pub machine_type: String, // TODO: enum
    pub operating_system: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NodeItem<Meta, Spec> {
    pub metadata: Meta,
    pub spec: Spec,
}

pub type Member = NodeItem<MemberMeta, MemberSpec>;

impl Member {
    pub fn version(&self) -> Result<Version<'_>> {
        let os = &self.spec.operating_system;
        let (_, rhs) = os.split_once(" ").context("invalid talos os string")?;
        rhs.strip_prefix("(")
            .and_then(|v| v.strip_suffix(")"))
            .and_then(Version::from)
            .context("invalid talos version")
    }

    pub fn external_ip(&self) -> Option<&Ipv4Addr> {
        self.spec
            .addresses
            .iter()
            .rev()
            .find(|addr| !addr.is_private())
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
}
