use std::path::{Path, PathBuf};

use gix::ObjectId;
use tokio::fs;
use tracing::{debug, info, instrument};

use super::Result;

#[derive(Debug)]
pub struct Repo {
    pub url: gix::Url,
    pub name: String,
    pub inner: gix::Repository,
    pub reference: String,
    pub path: PathBuf,
}

impl Repo {
    #[instrument(skip_all, fields(url = &url.to_string(), dir = ?dir.as_ref()))]
    async fn clone(url: gix::Url, dir: impl AsRef<Path>) -> Result<gix::Repository> {
        if dir.as_ref().exists() {
            fs::remove_dir_all(dir.as_ref()).await?;
        }
        fs::create_dir_all(dir.as_ref()).await?;

        debug!("preparing repository clone repository");
        let mut prepare_clone = gix::prepare_clone(url, dir)?;

        // TODO: tokio?

        let (mut prepare_checkout, _) = prepare_clone
            .fetch_then_checkout(gix::progress::Discard, &gix::interrupt::IS_INTERRUPTED)?;

        debug!("checkout out repository");
        let (repo, _) = prepare_checkout
            .main_worktree(gix::progress::Discard, &gix::interrupt::IS_INTERRUPTED)?;

        info!("repository cloned");

        Ok(repo)
    }

    pub async fn open(url: impl AsRef<str>, branch: &str, path: PathBuf) -> Result<Self> {
        let url = gix::url::parse(url.as_ref().into()).expect("invalid git url");
        let name = url
            .path
            .to_string()
            .trim_end_matches('/')
            .rsplit('/')
            .next()
            .unwrap_or("repo")
            .trim_end_matches(".git")
            .to_string();
        let inner = Self::clone(url.clone(), &path).await?;
        let reference = format!("refs/remotes/origin/{branch}");
        Ok(Self {
            url,
            name,
            inner,
            reference,
            path,
        })
    }

    pub async fn pull_latest(&self) -> Result<ObjectId> {
        let remote = self.inner.find_remote("origin").unwrap();

        debug!("fetching from remote...");
        let connection = remote
            .connect(gix::remote::Direction::Fetch)
            .unwrap()
            .prepare_fetch(gix::progress::Discard, Default::default())
            .unwrap();

        let outcome = connection
            .receive(gix::progress::Discard, &Default::default())
            .unwrap();
        debug!("fetched {} refs", outcome.ref_map.mappings.len());

        let head = self.inner.head()?;
        let branch_name = head.referent_name().ok_or("Not on a branch").unwrap();

        info!("pull completed for branch: {}", branch_name);

        self.revision_id().await
    }

    pub async fn revision_id(&self) -> Result<ObjectId> {
        let mut reference = self.inner.find_reference(&self.reference)?;
        let id = reference.peel_to_id_in_place()?;
        Ok(id.into())
    }
}
