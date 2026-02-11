use std::process::Stdio;

use anyhow::Result;
use tokio::io::{AsyncBufReadExt, AsyncRead, BufReader};
use tokio::process::Command;
use tracing::debug;

use crate::Context;
use crate::talos::Member;

fn proxy_stdio<R>(reader: R)
where
    R: AsyncRead + Unpin + Send + 'static,
{
    let mut lines = BufReader::new(reader).lines();

    tokio::spawn(async move {
        while let Ok(Some(line)) = lines.next_line().await {
            debug!("{line}")
        }
    });
}

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
