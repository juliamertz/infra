use anyhow::{Context, Result};
use jiff::{Timestamp, Unit};
use k8s_openapi_ext::{
    PodGetExt,
    corev1::{ContainerStateRunning, ContainerStatus, Pod},
};
use kube::{Api, Client, ResourceExt, api::ListParams};
use std::{ffi::OsStr, time::Duration};
use tokio::time::sleep;
use tracing::{debug, info, instrument};

pub trait CommandExt {
    fn bool_flag<S: AsRef<OsStr>>(&mut self, flag: S, cond: bool) -> &mut Self;
}

impl CommandExt for tokio::process::Command {
    fn bool_flag<S: AsRef<OsStr>>(&mut self, flag: S, cond: bool) -> &mut Self {
        match cond {
            true => self.arg(flag),
            false => self,
        }
    }
}

pub trait DurationExt {
    fn from_minutes(minutes: u64) -> Self;
    fn from_hours(hours: u64) -> Self;
    fn from_days(days: u64) -> Self;
    fn from_weeks(weeks: u64) -> Self;
}

impl DurationExt for std::time::Duration {
    fn from_minutes(minutes: u64) -> Self {
        Self::from_secs(60 * minutes)
    }
    fn from_hours(hours: u64) -> Self {
        DurationExt::from_minutes(60 * hours)
    }
    fn from_days(days: u64) -> Self {
        DurationExt::from_hours(24 * days)
    }
    fn from_weeks(weeks: u64) -> Self {
        DurationExt::from_days(7 * weeks)
    }
}

pub trait PodExt {
    fn is_healthy(&self) -> bool;
}

impl PodExt for k8s_openapi::api::core::v1::Pod {
    #[instrument(skip(self), fields(name = self.name_any()))]
    fn is_healthy(&self) -> bool {
        let Some(status) = self.status.as_ref() else {
            return false;
        };

        let running_healthy = |state: &ContainerStateRunning| {
            state.started_at.as_ref().map(|started_at| {
                let now = Timestamp::now();
                now.since((Unit::Second, started_at.0))
                    .map(|span| span.get_seconds() > 15)
                    .unwrap_or(false)
            })
        };

        let container_ready = |status: &ContainerStatus| {
            let Some(state) = status.state.as_ref() else {
                return false;
            };

            if state
                .terminated
                .as_ref()
                .map(|terminated| terminated.reason == Some("Completed".into()))
                .unwrap_or_default()
            {
                return true;
            }

            let started = status.started == Some(true);
            let not_terminated = state.terminated.is_none();
            let not_waiting = state.waiting.is_none();
            let settled = state
                .running
                .as_ref()
                .map(running_healthy)
                .flatten()
                .unwrap_or_default();

            let ready = status.ready && started && not_terminated && not_waiting && settled;

            if !ready {
                tracing::warn!({ status.ready, started, not_terminated, not_waiting, settled }, "not ready");
            }

            ready
        };

        status
            .container_statuses
            .as_ref()
            .map(|statuses| statuses.iter().all(container_ready))
            .unwrap_or_default()
    }
}

pub trait NodeApiExt {
    async fn is_ready(&self, name: &str) -> Result<bool>;
    async fn is_cordoned(&self, name: &str) -> Result<bool>;
    async fn wait_until_healthy(&self, client: Client, name: &str) -> Result<bool>;
}

impl NodeApiExt for kube::Api<k8s_openapi::api::core::v1::Node> {
    async fn is_ready(&self, name: &str) -> Result<bool> {
        let node = self.get(name).await?;
        let conditions = node
            .status
            .context("missing node status")?
            .conditions
            .unwrap_or_default();

        Ok(conditions
            .into_iter()
            .any(|cond| cond.type_ == "Ready" && cond.status == "True"))
    }

    async fn is_cordoned(&self, name: &str) -> Result<bool> {
        let node = self.get(name).await?;
        let taints = node
            .spec
            .context("missing node spec")?
            .taints
            .unwrap_or_default();

        Ok(taints.into_iter().any(|taint| {
            taint.key == "node.kubernetes.io/unschedulable" && taint.effect == "NoSchedule"
        }))
    }

    /// Make sure all scheduled workloads are running
    #[instrument(skip(self, client), err(Debug))]
    async fn wait_until_healthy(&self, client: Client, name: &str) -> Result<bool> {
        let pods = Api::<Pod>::all(client);
        let list_params = ListParams {
            field_selector: Some(format!("spec.nodeName={name}")),
            ..Default::default()
        };

        let interval = Duration::from_secs(5);

        loop {
            let list = pods.list(&list_params).await?;
            let count = list.items.len();

            info!("{count} pods scheduled on {name}");

            let healthy_pods = list.items.iter().filter(|pod| pod.is_healthy());
            let healthy_count = healthy_pods.count();

            if healthy_count == count {
                return Ok(true);
            }

            info!(
                "{} out of {count} workloads not ready yet",
                count - healthy_count
            );

            sleep(interval).await;
        }
    }
}
