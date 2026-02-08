mod cert_approver;
mod hostdns;
mod sync;

use clap::{Parser, Subcommand};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    HostDns,
    Sync(sync::Opts),
    CertApprover {
        /// CIDR range for allowed internal IPs (e.g., 10.0.0.0/8)
        #[arg(long, env = "INTERNAL_IP_RANGE", default_value = "10.0.0.0/8")]
        internal_ip_range: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let opts = Cli::parse();

    match opts.command {
        Command::HostDns => hostdns::run().await?,
        Command::Sync(opts) => sync::run(opts).await?,
        Command::CertApprover { internal_ip_range } => {
            cert_approver::run(cert_approver::Config { internal_ip_range }).await?
        }
    };

    Ok(())
}
