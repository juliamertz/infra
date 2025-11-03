use std::ffi::OsStr;

pub trait CommandExt {
    fn opt_arg<S: AsRef<OsStr>>(&mut self, arg: Option<S>) -> &mut Self;
    fn bool_flag<S: AsRef<OsStr>>(&mut self, flag: S, cond: bool) -> &mut Self;
}

impl CommandExt for tokio::process::Command {
    fn opt_arg<S: AsRef<OsStr>>(&mut self, arg: Option<S>) -> &mut Self {
        match arg {
            Some(arg) => self.arg(arg),
            None => self,
        }
    }

    fn bool_flag<S: AsRef<OsStr>>(&mut self, flag: S, cond: bool) -> &mut Self {
        match cond {
            true => self.arg(flag),
            false => self,
        }
    }
}
