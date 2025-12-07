use std::net::SocketAddr;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use metrics::{Gauge, gauge};
use metrics_exporter_prometheus::PrometheusBuilder;
use tokio::net::UdpSocket;
use tokio::time::{sleep, timeout};
use tracing::error;

struct Metrics {
    up: Gauge,
    players_online: Gauge,
    players_maximum: Gauge,
    ping_ms: Gauge,
}

pub async fn serve(host: &str) -> Result<()> {
    let builder = PrometheusBuilder::new();
    builder.install()?;

    let metrics = Metrics {
        up: gauge!("valheim_server_up"),
        players_online: gauge!("valheim_players_online"),
        players_maximum: gauge!("valheim_players_maximum"),
        ping_ms: gauge!("valheim_ping_ms"),
    };

    loop {
        match query_server(host, &metrics).await {
            Ok(_) => {}
            Err(e) => error!("failed to update metrics: {e}"),
        }

        sleep(Duration::from_secs(5)).await;
    }
}

async fn query_server(host: &str, metrics: &Metrics) -> Result<u64> {
    let ip = dns_lookup::lookup_host(host)?
        .next()
        .with_context(|| format!("unable to lookup DNS for '{host}'"))?;

    let client = QueryClient::new(host);

    let Ok(ping) = client.ping().await else {
        metrics.up.set(0);
        metrics.players_online.set(0);
        metrics.players_maximum.set(0);
        metrics.ping_ms.set(0);
        return Ok(0);
    };

    let response = gamedig::valheim::query(&ip, None)?;

    metrics.up.set(1);
    metrics.players_online.set(response.players_online);
    metrics.players_maximum.set(response.players_maximum);
    metrics.ping_ms.set(ping.as_millis() as f64);

    Ok(response.players_online as u64)
}

const A2S_INFO_QUERY: &[u8] = b"\xFF\xFF\xFF\xFF\x54Source Engine Query\0";

struct QueryClient {
    host: String,
    port: u16,
}

impl QueryClient {
    pub fn new(host: impl Into<String>) -> Self {
        Self {
            host: host.into(),
            port: 2457,
        }
    }

    pub async fn ping(&self) -> Result<Duration> {
        let addr = self.resolve()?;
        let socket = UdpSocket::bind("0.0.0.0:0").await?;

        let start = Instant::now();
        socket.send_to(A2S_INFO_QUERY, addr).await?;

        let mut buf = [0u8; 1024];
        timeout(Duration::from_secs(5), socket.recv_from(&mut buf))
            .await
            .context("timeout waiting for response")?
            .context("failed to receive")?;

        Ok(start.elapsed())
    }

    fn resolve(&self) -> Result<SocketAddr> {
        let ip = dns_lookup::lookup_host(&self.host)?
            .next()
            .with_context(|| format!("no DNS records for '{}'", self.host))?;

        Ok(SocketAddr::new(ip, self.port))
    }
}
