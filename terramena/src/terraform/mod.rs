pub mod output;

use std::{collections::BTreeMap, ffi::OsStr, path::Path};

use output::Output;

fn cmd(bin: impl AsRef<Path>, args: &[impl AsRef<OsStr>]) -> String {
    let output = std::process::Command::new(bin.as_ref())
        .args(args)
        .output()
        .unwrap();

    String::from_utf8_lossy(&output.stdout).to_string()
}

pub fn get_outputs(opts: &super::Opts) -> BTreeMap<String, Output> {
    let args: Vec<Option<String>> = vec![
        opts.chdir
            .clone()
            .map(|ref path| format!("-chdir={}", path.to_str().unwrap())),
        Some("output".into()),
        Some("-json".into()),
    ];

    let args = args.iter().flatten().collect::<Vec<_>>();
    let stdout = cmd(&opts.bin, &args);

    // let de: BTreeMap<String, output::Output> = serde_json::from_str(&stdout).unwrap();
    // let hosts = de
    //     .into_iter()
    //     .filter(|(_, value)| {
    //         matches!(
    //             value,
    //             Output {
    //                 value: output::Value::NixOsHost(_),
    //                 ..
    //             }
    //         )
    //     })
    //     .collect();
    //
    // hosts
    serde_json::from_str(&stdout).unwrap()
}
