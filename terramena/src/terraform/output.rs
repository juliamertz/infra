use serde::{Deserialize, Deserializer};
use serde_json::Value;

#[derive(Debug, Deserialize)]
struct RawOutput {
    sensitive: bool,
    #[serde(rename = "type")]
    _ty: Value,
    value: Value,
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
        Ok(Output {
            sensitive: raw.sensitive,
            value: raw.value,
        })
    }
}
