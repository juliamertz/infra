use std::path::{Path, PathBuf};

use gix::ObjectId;
use tokio::fs;
use tracing::{debug, info, instrument};

use super::Result;

#[derive(Debug)]
pub struct Repo {
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
        let inner = Self::clone(url.clone(), &path).await?;
        let reference = format!("refs/remotes/origin/{branch}");
        Ok(Self {
            inner,
            reference,
            path,
        })
    }

    pub async fn pull_latest(&self) -> Result<ObjectId> {
        tokio::task::block_in_place(|| {
            let remote = self.inner.find_remote("origin").unwrap();
            debug!("fetching from remote");
            let outcome = remote
                .connect(gix::remote::Direction::Fetch)
                .unwrap()
                .prepare_fetch(gix::progress::Discard, Default::default())
                .unwrap()
                .receive(gix::progress::Discard, &Default::default())
                .unwrap();
            debug!("fetched {} refs", outcome.ref_map.mappings.len());

            let oid = self
                .inner
                .find_reference(&self.reference)?
                .id()
                .detach();

            self.checkout(oid)?;
            Ok(oid)
        })
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

        let tree = self
            .inner
            .find_object(oid)
            .unwrap()
            .peel_to_tree()
            .unwrap();
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

        info!("checked out {oid}");
        Ok(())
    }
}
