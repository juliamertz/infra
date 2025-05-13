mod colmena;
mod terraform;
mod utils;

use askama::Template;
use clap::{Parser, Subcommand};
use std::{net::IpAddr, path::PathBuf, str::FromStr};
use thiserror::Error;

#[derive(Parser, Clone)]
#[command(version, about, long_about = None)]
struct Opts {
    #[arg(short, long, default_value = "tofu")]
    bin: PathBuf,

    #[arg(long)]
    chdir: Option<PathBuf>,

    #[arg(short, long)]
    config_path: PathBuf,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand, Clone)]
enum Command {
    Build {
        #[arg(short, long)]
        list: bool,
    },
    Apply {
        #[arg(short, long)]
        on: Option<String>,
    },
}

#[derive(Error, Debug)]
enum OutputError {
    #[error("terraform output does not match the expected type")]
    InvalidType,
    #[error("output is missing expected field: {name}")]
    MissingField { name: String },
}

#[derive(Debug)]
struct Host {
    config: PathBuf,
    ip: IpAddr,
    hostname: String,
    ssh_user: String,
    ssh_port: u32,
}

impl TryFrom<serde_json::Value> for Host {
    type Error = OutputError;

    fn try_from(value: serde_json::Value) -> Result<Self, Self::Error> {
        let serde_json::Value::Object(obj) = value else {
            return Err(OutputError::InvalidType);
        };

        let Some(serde_json::Value::String(ty)) = obj.get("_type") else {
            return Err(OutputError::MissingField {
                name: "_type".into(),
            });
        };

        dbg!(&obj);

        let Some(serde_json::Value::String(config_path)) = obj.get("config") else {
            panic!("host missing config field")
        };

        let Some(serde_json::Value::String(ip)) = obj.get("ip") else {
            panic!("host missing ip field")
        };

        let Some(serde_json::Value::String(hostname)) = obj.get("hostname") else {
            panic!("host missing hostname field")
        };

        let Some(serde_json::Value::String(ssh_user)) = obj.get("ssh_user") else {
            panic!("host missing ssh_user field")
        };

        let Some(serde_json::Value::Number(ssh_port)) = obj.get("ssh_port") else {
            panic!("host missing ssh_port field")
        };

        Ok(Host {
            hostname: hostname.to_string(),
            config: config_path.into(),
            ip: IpAddr::from_str(ip).unwrap(),
            ssh_user: ssh_user.to_string(),
            // ssh_port: todo!(),
            // ssh_port: ssh_port.try_into().unwrap(),
        });
    }
}

fn main() {
    let opts = Opts::parse();

    let outputs = terraform::get_outputs(&opts);
    let hosts: Vec<Host> = outputs
        .values()
        .map(|output| output.value.clone().try_into().unwrap())
        .collect();

    dbg!(&hosts);

    // match &opts.command {
    //     Some(Commands::Test { list }) => {
    //         if *list {
    //             println!("Printing testing lists...");
    //         } else {
    //             println!("Not printing testing lists...");
    //         }
    //     }
    //     None => {}
    // }
}

// #[derive(Template)]
// #[template(path = "hive.nix")]
// struct HiveTemplate<'a> {
//     hosts: Vec<(&'a Host, PathBuf)>,
//     defaults: PathBuf,
// }
