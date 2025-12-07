mod cert_approver;
mod hostdns;
mod valheim;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    HostDns,
    CertApprover {
        /// CIDR range for allowed internal IPs (e.g., 10.0.0.0/8)
        #[arg(long, env = "INTERNAL_IP_RANGE", default_value = "10.0.0.0/8")]
        internal_ip_range: String,
    },
    Valheim {
        #[arg(long, env = "HOST")]
        host: String,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt().init();

    let opts = Cli::parse();

    match opts.command {
        Command::HostDns => hostdns::run().await?,
        Command::CertApprover { internal_ip_range } => {
            cert_approver::run(cert_approver::Config { internal_ip_range }).await?
        }
        Command::Valheim { host } => valheim::serve(&host).await?,
    };

    Ok(())
}
