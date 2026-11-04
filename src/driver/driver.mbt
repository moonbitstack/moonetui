// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
#derive(Debug)
pub(all) suberror TtyError {
  Io(String)
}

///|
pub(open) trait Driver {
  fn start(Self) -> Unit raise TtyError
  fn stop(Self) -> Unit raise TtyError
  fn write(Self, String) -> Unit raise TtyError
  fn flush(Self) -> Unit raise TtyError
  fn size(Self) -> @geom.Size raise TtyError
  fn poll(Self, Int32) -> Bytes raise TtyError
  fn now(Self) -> Int32
}

///|
pub extend TtyError with Debug::{to_repr}
