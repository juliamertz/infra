use std::ffi::OsStr;

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

pub trait NodeApiExt {
    async fn is_ready(&self, name: &str) -> bool;
}

impl NodeApiExt for kube::Api<k8s_openapi::api::core::v1::Node> {
    async fn is_ready(&self, name: &str) -> bool {
        self.get_status(name)
            .await
            .map(|node| {
                node.status
                    .and_then(|node| node.conditions)
                    .unwrap_or_default()
                    .iter()
                    .any(|cond| cond.type_ == "Ready" && cond.status == "True")
            })
            .unwrap_or_default()
    }
}
