use std::{ffi::OsStr, path::Path};

pub fn cmd(bin: impl AsRef<Path>, args: &[impl AsRef<OsStr>]) -> String {
    let output = std::process::Command::new(bin.as_ref())
        .args(args)
        .output()
        .unwrap();

    String::from_utf8_lossy(&output.stdout).to_string()
}

