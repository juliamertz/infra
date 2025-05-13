pub mod output;

use output::Output;
use std::collections::BTreeMap;

pub fn get_outputs(opts: &super::Opts) -> BTreeMap<String, Output> {
    let args: Vec<Option<String>> = vec![
        opts.chdir
            .clone()
            .map(|ref path| format!("-chdir={}", path.to_str().unwrap())),
        Some("output".into()),
        Some("-json".into()),
    ];

    let args = args.iter().flatten().collect::<Vec<_>>();
    let stdout = crate::utils::cmd(&opts.bin, &args);

    serde_json::from_str(&stdout).unwrap()
}
