use tokio::io::{AsyncBufReadExt, AsyncRead, BufReader};
use tracing::{debug};

pub fn proxy_stdio<R>(reader: R)
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
