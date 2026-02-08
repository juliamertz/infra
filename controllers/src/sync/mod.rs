use std::{path::PathBuf, time::Duration};

use clap::Parser;
use kube::Client;
use tokio::{fs, time::sleep};
use tracing::{debug, error, info, instrument};

mod nix;
mod reconcile;
mod repo;
mod state;

use repo::Repo;
use state::State;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("kube error: {0}")]
    Kube(#[from] kube::Error),
    #[error("git error: {0}")]
    Git(#[from] gix::Error),
    #[error("clone error: {0}")]
    Clone(#[from] gix::clone::Error),
    #[error("fetch error: {0}")]
    Fetch(#[from] gix::clone::fetch::Error),
    #[error("checkout error: {0}")]
    Checkout(#[from] gix::clone::checkout::main_worktree::Error),
    #[error("failed to peel reference: {0}")]
    Peel(#[from] gix::reference::peel::Error),
    #[error("failed find reference: {0}")]
    FindReference(#[from] gix::reference::find::existing::Error),
    #[error("failed to parse git URL: {0}")]
    ParseURL(#[from] gix::url::parse::Error),
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

    let interval = Duration::from_secs(opts.interval);
    let ctx = Ctx {
        opts,
        state,
        repo,
        kube,
    };

    loop {
        if let Err(err) = run_once(&ctx).await {
            error!(
                { err = &err as &dyn std::error::Error },
                "error while reconciling"
            );
        };

        sleep(interval).await;
    }
}

#[instrument(skip_all, err(Debug))]
async fn run_once(ctx: &Ctx) -> Result<()> {
    let head = ctx.repo.pull_latest().await?;
    let state = ctx.state.get().await?;

    let span = tracing::info_span!("reconcile", ?head);
    let _guard = span.enter();

    if let Some((curr, _)) = state
        && curr == head
    {
        debug!("already up to date");
        return Ok(());
    }

    info!("building latest revision");
    let built_objects = nix::build_kubenix(&ctx.repo.path, &ctx.opts.kubenix_attrpath).await?;

    let plan = if let Some((_, objects)) = state {
        if built_objects == objects {
            info!("built objects haven't changed");
            return Ok(());
        }
        // TODO: needless clone
        reconcile::Plan::new(objects, built_objects.clone())
    } else {
        reconcile::Plan::new(vec![], built_objects.clone())
    };

    let kube = ctx.kube.clone();
    if let Err(errors) = plan.apply(kube).await {
        error!(
            "failed to run {} out of {} actions",
            errors.len(),
            plan.actions.len()
        );
    } else {
        info!("succesfully applied revisio");
    }

    ctx.state.set(&head, &built_objects).await?;

    Ok(())
}
