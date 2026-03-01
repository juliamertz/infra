use std::{path::PathBuf, time::Duration};

use clap::Parser;
use kube::{Client, api::DynamicObject};
use sha2::{Digest, Sha256, digest::Output};
use tokio::fs;
use tracing::{debug, error, info, instrument};

mod nix;
mod reconcile;
mod repo;
mod state;
mod vals;

use repo::Repo;
use state::State;

pub const MANAGER_NAME: &str = "sync-controller";

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("kube error: {0}")]
    Kube(#[from] kube::Error),
    #[error("git error: {0}")]
    Repo(#[from] repo::Error),
    #[error("nix build error: {0}")]
    Nixbuild(#[from] nix::BuildError),
    #[error("reconcile error: {0}")]
    Reconcile(#[from] reconcile::Error),
}

pub type Result<T, E = Error> = core::result::Result<T, E>;

#[derive(Debug, Parser)]
pub struct Opts {
    #[clap(long, env = "GIT_URL")]
    git_url: String,
    #[clap(long, env = "STATE_DIR", default_value = "repo")]
    state_dir: PathBuf,
    #[clap(long, env = "KUBENIX_ATTRPATH", default_value = ".#manifest")]
    kubenix_attrpath: String,
    #[clap(long, env = "INTERVAL", default_value = "300")]
    interval: u64,
}

struct Ctx {
    opts: Opts,
    state: State,
    repo: Repo,
    kube: Client,
}

pub async fn run(opts: Opts) -> Result<()> {
    let Opts {
        ref state_dir,
        ref git_url,
        ..
    } = opts;

    if !state_dir.exists() {
        fs::create_dir_all(&state_dir).await?;
    }

    let kube = Client::try_default().await?;
    let state = State::new(kube.clone());
    let repo = Repo::open(&git_url, "main", state_dir.clone()).await?;

    let ctx = Ctx {
        opts,
        state,
        repo,
        kube,
    };

    let mut interval = tokio::time::interval(Duration::from_secs(ctx.opts.interval));
    interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        interval.tick().await;

        if let Err(err) = run_once(&ctx).await {
            error!(
                { err = &err as &dyn std::error::Error },
                "error while reconciling"
            );
        };
    }
}

fn hash(objects: &[DynamicObject]) -> Result<Output<Sha256>> {
    let mut hash = Sha256::default();
    for obj in objects {
        let bytes = serde_json::to_vec(obj)?;
        hash.update(&bytes);
    }
    Ok(hash.finalize())
}

#[instrument(skip_all, err(Debug))]
async fn run_once(ctx: &Ctx) -> Result<()> {
    let head = ctx.repo.fetch_latest().await?;
    let state = ctx.state.get().await?;

    let span = tracing::info_span!("reconcile", ?head);
    let _guard = span.enter();

    if let Some((ref curr, _)) = state
        && curr == &head
    {
        debug!("already up to date at {head}");
        return Ok(());
    }

    info!(
        "revision changed: {} -> {head}",
        state
            .as_ref()
            .map(|(id, _)| id.to_string())
            .unwrap_or_else(|| "none".into())
    );

    ctx.repo.pull(head).await?;

    info!("building latest revision");

    let built_objects = nix::build_kubenix(&ctx.repo.path, &ctx.opts.kubenix_attrpath).await?;

    debug!("build produced {} objects", built_objects.len());

    let plan = if let Some((_, objects)) = state {
        let old_hash = hash(&objects)?;
        let new_hash = hash(&built_objects)?;
        debug!("old hash: {old_hash:x}, new hash: {new_hash:x}");
        if old_hash == new_hash {
            debug!("object hashes match, skipping reconcile");
            ctx.state.set(&head, &built_objects).await?;
            return Ok(());
        }
        reconcile::Plan::new(objects, built_objects.clone())
    } else {
        debug!("no previous state, performing initial sync");
        reconcile::Plan::new(vec![], built_objects.clone())
    };

    info!("applying {} actions", plan.actions.len());
    let kube = ctx.kube.clone();
    if let Err(errors) = plan.apply(kube).await {
        error!(
            "failed to run {} out of {} actions",
            errors.len(),
            plan.actions.len()
        );
    } else {
        info!("successfully applied revision {head}");
    }

    ctx.state.set(&head, &built_objects).await?;

    Ok(())
}
