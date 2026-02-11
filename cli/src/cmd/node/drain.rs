use std::process::Stdio;

use anyhow::Result;
use common::proxy_stdio;
use tokio::process::Command;

use crate::Context;
use crate::talos::Member;

pub async fn handle(_ctx: Context, member: &Member) -> Result<()> {
    let mut child = Command::new("kubectl")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .arg("drain")
        .arg(member.hostname())
        .arg("--ignore-daemonsets")
        .arg("--delete-emptydir-data")
        .arg("--timeout=5m")
        .spawn()?;

    proxy_stdio(child.stdout.take().unwrap());
    proxy_stdio(child.stderr.take().unwrap());

    let status = child.wait().await?;
    if !status.success() {
        anyhow::bail!("failed to drain node");
    }

    Ok(())
}
