use std::{
    env,
    ops::Index,
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::Context;
use gix::ObjectId;
use reqwest::header::HeaderMap;
use serde::Deserialize;
use tokio::fs;
use tracing::{debug, info, instrument};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("i/o error: {0}")]
    Io(#[from] std::io::Error),
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
    #[error("invalid utf8: {0}")]
    Utf8(#[from] std::str::Utf8Error),
    #[error("http errorj: {0}")]
    Http(#[from] reqwest::Error),
}

pub type Result<T, E = Error> = core::result::Result<T, E>;

#[derive(Debug)]
pub struct Repo {
    pub inner: gix::Repository,
    pub reference: String,
    pub path: PathBuf,
    pub owner: String,
    pub repo: String,
    pub branch: String,
    gh_http: reqwest::Client,
}

impl Repo {
    #[instrument(skip_all, fields(url = &url.to_string(), dir = ?dir.as_ref()))]
    async fn clone(url: gix::Url, dir: impl AsRef<Path>) -> Result<gix::Repository> {
        if dir.as_ref().exists() {
            fs::remove_dir_all(dir.as_ref()).await?;
        }
        fs::create_dir_all(dir.as_ref()).await?;

        let dir = dir.as_ref().to_owned();
        let repo = tokio::task::block_in_place(|| -> Result<_> {
            debug!("preparing clone");
            let mut prepare_clone = gix::prepare_clone(url, &dir)?;

            let (mut prepare_checkout, _) = prepare_clone
                .fetch_then_checkout(gix::progress::Discard, &gix::interrupt::IS_INTERRUPTED)?;

            let (repo, _) = prepare_checkout
                .main_worktree(gix::progress::Discard, &gix::interrupt::IS_INTERRUPTED)?;

            Ok(repo)
        })?;

        info!("repository cloned");
        Ok(repo)
    }

    pub async fn open(url: impl AsRef<str>, branch: &str, path: PathBuf) -> Result<Self> {
        let url = gix::url::parse(url.as_ref().into()).expect("invalid git url");
        let url_path = url.path.to_string();
        let (owner, repo) = url_path
            .as_str()
            .strip_prefix("/")
            .unwrap_or(&url_path)
            .strip_suffix(".git")
            .unwrap_or(&url_path)
            .split_once("/")
            .unwrap();

        let inner = Self::clone(url.clone(), &path).await?;
        let reference = format!("refs/remotes/origin/{branch}");

        let gh_http = reqwest::Client::builder()
            .default_headers({
                let mut headers = HeaderMap::new();
                let pat = env::var("GITHUB_PAT").expect("GITHUB_PAT environment variable set");
                headers.insert("Accept", "application/vnd.github+json".parse().unwrap());
                headers.insert("Authorization", format!("Bearer {pat}",).parse().unwrap());
                headers.insert("User-Agent", "Infra-App".parse().unwrap());
                headers.insert("X-GitHub-Api-Version", "2022-11-28".parse().unwrap());
                headers
            })
            .build()?;

        Ok(Self {
            inner,
            reference,
            path,
            branch: branch.to_string(),
            owner: owner.to_string(),
            repo: repo.to_string(),
            gh_http,
        })
    }

    pub async fn pull(&self, oid: ObjectId) -> Result<ObjectId> {
        tokio::task::block_in_place(|| {
            // let remote = self.inner.find_remote("origin").unwrap();
            // debug!("fetching from remote");
            // let outcome = remote
            //     .connect(gix::remote::Direction::Fetch)
            //     .unwrap()
            //     .prepare_fetch(gix::progress::Discard, Default::default())
            //     .unwrap()
            //     .receive(gix::progress::Discard, &Default::default())
            //     .unwrap();
            // debug!("fetched {} refs", outcome.ref_map.mappings.len());
            // let oid = self.inner.find_reference(&self.reference)?.id().detach();

            self.checkout(oid)?;
            Ok(oid)
        })
    }

    pub async fn fetch_latest(&self) -> Result<ObjectId> {
        #[derive(Deserialize)]
        struct Commit {
            sha: String,
        }

        #[derive(Deserialize)]
        struct Response {
            commit: Commit,
        }

        let url = format!(
            "https://api.github.com/repos/{owner}/{repo}/branches/{branch}",
            owner = self.owner,
            repo = self.repo,
            branch = self.branch,
        );
        let response = self
            .gh_http
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json::<Response>()
            .await?;

        let id = ObjectId::from_str(&response.commit.sha).unwrap();
        Ok(id)
    }

    fn checkout(&self, oid: ObjectId) -> Result<()> {
        debug!("cleaning worktree at {:?}", self.path);
        for entry in std::fs::read_dir(&self.path)? {
            let entry = entry?;
            if entry.file_name() == ".git" {
                continue;
            }
            if entry.file_type()?.is_dir() {
                std::fs::remove_dir_all(entry.path())?;
            } else {
                std::fs::remove_file(entry.path())?;
            }
        }

        let tree = self.inner.find_object(oid).unwrap().peel_to_tree().unwrap();
        debug!("building index from tree {}", tree.id);
        let mut index =
            gix::index::State::from_tree(&tree.id, &self.inner.objects, Default::default())
                .unwrap();

        debug!(
            "checking out {} index entries to worktree",
            index.entries().len()
        );
        gix::worktree::state::checkout(
            &mut index,
            &self.path,
            self.inner.objects.clone(),
            &gix::progress::Discard,
            &gix::progress::Discard,
            &gix::interrupt::IS_INTERRUPTED,
            gix::worktree::state::checkout::Options::default(),
        )
        .unwrap();

        let index_path = self.inner.git_dir().join("index");
        let mut index_file = gix::index::File::from_state(index, index_path);
        index_file.write(Default::default()).unwrap();

        debug!("checked out {oid}");
        Ok(())
    }
}
