mod terraform;

use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser, Clone)]
#[command(version, about, long_about = None)]
struct Opts {
    #[command(subcommand)]
    command: Option<Commands>,

    #[arg(short, long, default_value = "tofu")]
    bin: PathBuf,

    #[arg(long)]
    chdir: Option<PathBuf>,
}

#[derive(Subcommand, Clone)]
enum Commands {
    /// does testing things
    Test {
        /// lists test values
        #[arg(short, long)]
        list: bool,
    },
}

fn main() {
    let opts = Opts::parse();

    let outputs = terraform::get_outputs(&opts);
    let hosts = outputs
        .values()
        .map(|v| v.value.clone())
        .filter_map(|v| match v {
            terraform::output::Value::NixosHost(host) => Some(host),
            _ => None,
        })
        .collect::<Vec<_>>();

    dbg!(&hosts);

    match &opts.command {
        Some(Commands::Test { list }) => {
            if *list {
                println!("Printing testing lists...");
            } else {
                println!("Not printing testing lists...");
            }
        }
        None => {}
    }
}
