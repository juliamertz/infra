use std::{
    net::IpAddr,
    path::{Path, PathBuf},
    str::FromStr,
};

use serde::{Deserialize, Deserializer};

#[derive(Debug, Deserialize)]
struct RawOutput {
    sensitive: bool,
    #[serde(rename = "type")]
    ty: serde_json::Value,
    value: serde_json::Value,
}

// TODO: factor this out and stick to base terraform types to export from here
// this could be abstracted later
#[derive(Debug, Clone, Deserialize)]
pub struct NixosHost {
    pub config: PathBuf,
    pub hostname: String,
    pub ip: IpAddr,
}

#[derive(Debug, Clone, Deserialize)]
pub enum Value {
    String(String),
    NixosHost(NixosHost),
}

#[derive(Debug)]
pub struct Output {
    pub sensitive: bool,
    pub value: Value,
}

impl<'de> Deserialize<'de> for Output {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let raw = RawOutput::deserialize(deserializer)?;

        let value = match &raw.ty {
            serde_json::Value::String(value) => match value.as_str() {
                "string" => {
                    let value = raw.value.to_string();
                    Value::String(value)
                }
                _ => unimplemented!(),
            },

            serde_json::Value::Array(value) => {
                let mut iter = value.iter();
                let ty = iter.next().expect("type identifier");
                match ty {
                    serde_json::Value::String(value) => match value.as_str() {
                        "object" => {
                            let serde_json::Value::Object(obj) = iter.next().unwrap() else {
                                unimplemented!();
                            };

                            if obj.get("_type").unwrap() != "string" {
                                unimplemented!();
                            }

                            let serde_json::Value::Object(obj) = raw.value else {
                                unimplemented!();
                            };

                            match obj.get("_type").unwrap() {
                                serde_json::Value::String(value) if value == "nixos_host" => {
                                    let serde_json::Value::String(ip) = obj.get("ip").unwrap()
                                    else {
                                        panic!("no good")
                                    };

                                    let serde_json::Value::String(hostname) =
                                        obj.get("hostname").unwrap()
                                    else {
                                        panic!("no good")
                                    };

                                    let serde_json::Value::String(config_path) =
                                        obj.get("config").unwrap()
                                    else {
                                        panic!("no good")
                                    };
                                    let config = PathBuf::from(config_path);

                                    Value::NixosHost(NixosHost {
                                        config,
                                        hostname: hostname.to_string(),
                                        ip: IpAddr::from_str(ip).unwrap(),
                                    })
                                }
                                _ => unimplemented!(),
                            }
                        }
                        _ => unimplemented!(),
                    },
                    _ => unimplemented!(),
                }
            }
            _ => unimplemented!(),
        };

        Ok(Output {
            sensitive: raw.sensitive,
            value,
        })
    }
}
