use anyhow::{Context as _, Result};
use clap::{Parser, Subcommand};

pub mod drain;
pub mod kick_dbs;
pub mod upgrade;

#[derive(Parser, Debug)]
pub struct Opts {
    #[arg(short, long)]
    node: String,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Drain,
    KickDbs,
    Upgrade(upgrade::Opts),
}

use crate::Context;

pub async fn handle(ctx: Context, opts: Opts) -> Result<()> {
    let member = ctx
        .talosctl
        .member(&opts.node)
        .context("node not found")?
        .to_owned();

    match opts.command {
        Command::Drain => drain::handle(ctx, &member).await,
        Command::KickDbs => kick_dbs::handle(ctx, &member).await,
        Command::Upgrade(upgrade_opts) => upgrade::handle(ctx, upgrade_opts, &opts.node).await,
    }
}
