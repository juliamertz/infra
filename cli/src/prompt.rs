use anyhow::Result;
use demand::Confirm;

pub fn confirm(msg: impl ToString) -> Result<bool> {
    Ok(Confirm::new(msg.to_string())
        .affirmative("Yes")
        .negative("No")
        .run()?)
}
