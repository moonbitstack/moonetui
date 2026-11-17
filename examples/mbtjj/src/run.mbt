// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The two loops meet here: what the model asks for, answered by jj, and what
// comes back put where the screen will read it.

///|
/// Read the log for the first time, or into a revset.
pub async fn Repo::open(self : Repo, revset~ : String = "") -> Unit {
  let req : Request = Log(revset~)
  self.serve(req)
}

///|
/// Answer one request. A command that fails puts jj's own words on the status
/// line and leaves what was there; a log that arrives keeps the cursor on the
/// revision it was on.
pub async fn Repo::serve(self : Repo, req : Request) -> Unit {
  match req {
    Log(revset~) => {
      let rows = read_log(self.root, revset~) catch {
        Failed(text~) => {
          self.fail(text)
          return
        }
      }
      self.set_log(rows)
    }
    Diff(change~) => {
      let lines = diff(self.root, change~) catch {
        Failed(text~) => {
          self.fail(text)
          return
        }
      }
      self.set_aside(lines)
    }
    Ops => {
      let lines = operations(self.root) catch {
        Failed(text~) => {
          self.fail(text)
          return
        }
      }
      self.set_aside(lines)
    }
  }
}
