use std::{io::Write, time::Duration};

use anyhow::{Context as _, Result};
use clap::Parser;
use k8s_openapi_ext::{
    authenticationv1::{TokenRequest, TokenRequestSpec},
    corev1::ServiceAccount,
};
use kube::{Api, api::PostParams};

use crate::{
    Context,
    ext::DurationExt,
    talos::kubeconfig::{NamedUser, User},
};

/// Get kubeconfig for service account
#[derive(Debug, Parser)]
pub struct Opts {
    // TODO: the node that is used shouldn't really matter for this command
    // remove this arg
    #[arg(long, short)]
    node_name: String,

    #[arg(long, short)]
    service_account: String,

    #[arg(long, short)]
    namespace: String,
}

pub async fn handle(ctx: Context, opts: Opts) -> Result<()> {
    let member = ctx
        .talosctl
        .member(&opts.node_name)
        .context("node not found")?;

    let mut kubeconfig = ctx.talosctl.get_kubeconfig(&member).await?;

    let service_accounts = Api::<ServiceAccount>::namespaced(ctx.kube.clone(), &opts.namespace);
    let service_account_name = opts.service_account;

    let expiration: Duration = DurationExt::from_weeks(16);
    let token_req = service_accounts
        .create_token_request(
            &service_account_name,
            &PostParams::default(),
            &TokenRequest {
                spec: TokenRequestSpec {
                    audiences: vec![],
                    bound_object_ref: None,
                    expiration_seconds: Some(expiration.as_secs() as i64),
                },
                ..Default::default()
            },
        )
        .await?;

    let token = token_req
        .status
        .context("token request has no status")?
        .token;

    let cluster = kubeconfig
        .clusters
        .first()
        .expect("atleast one cluster in kubeconfig");
    let cluster_name = cluster.name.clone();

    kubeconfig.set_user(NamedUser {
        name: format!("{service_account_name}@{cluster_name}"),
        user: User::token(token),
    });
    kubeconfig.set_namespace(&opts.namespace);

    let kubeconfig_yaml = serde_yaml::to_string(&kubeconfig).expect("Failed to serialize to YAML");

    std::io::stdout()
        .write_all(kubeconfig_yaml.as_str().as_bytes())
        .unwrap();

    Ok(())
}
