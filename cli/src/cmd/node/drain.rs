use anyhow::Result;
use tokio::process::Command;

use crate::Context;
use crate::talos::Member;

pub async fn handle(_ctx: Context, member: &Member) -> Result<()> {
    // TODO: find some way to pipe stderr of stdout to tracing with nice filters/formatting
    let output = Command::new("kubectl")
        .arg("drain")
        .arg(member.hostname())
        .arg("--ignore-daemonsets")
        .arg("--delete-emptydir-data")
        .arg("--timeout=5m")
        .spawn()?
        .wait_with_output()
        .await?;

    if !output.status.success() {
        anyhow::bail!("failed to drain node");
    }

    Ok(())
}
