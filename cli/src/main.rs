use std::sync::Arc;

use anyhow::Result;
use clap::Parser;
use kube::Client as KubeClient;
use talos::TalosFactory;
use tracing::Level;

mod cmd;
mod cnpg;
mod ext;
mod talos;

use crate::talos::TalosCtl;

#[derive(Parser)]
struct Opts {
    #[command(subcommand)]
    command: Subcommand,
}

#[derive(Debug, clap::Subcommand)]
enum Subcommand {
    Node(cmd::node::Opts),
    GetKubeconfig(cmd::get_kubeconfig::Opts),
    // Build and uploader talos image to hetzner
    // UploadImage {
    //     #[arg(long, short)]
    //     version: String,
    //
    //     #[arg(long, short)]
    //     customization_path: Option<PathBuf>,
    // },
}

#[derive(Clone)]
pub struct Context {
    pub kube: KubeClient,
    pub factory: Arc<TalosFactory>,
    pub talosctl: Arc<TalosCtl>,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .pretty()
        .init();

    rustls::crypto::ring::default_provider()
        .install_default()
        .expect("Failed to install rustls crypto provider");

    let opts = Opts::parse();

    let kube = KubeClient::try_default().await?;
    let factory = TalosFactory::default();
    let talosctl = TalosCtl::try_new().await?;
    let ctx = Context {
        kube,
        factory: Arc::from(factory),
        talosctl: Arc::from(talosctl),
    };

    match opts.command {
        Subcommand::Node(opts) => cmd::node::handle(ctx, opts).await,
        Subcommand::GetKubeconfig(opts) => cmd::get_kubeconfig::handle(ctx, opts).await,
    }
}
