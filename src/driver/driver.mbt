// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
#derive(Debug)
pub(all) suberror Refused {
  Io(String)
}

///|
pub(open) trait Driver {
  fn start(Self) -> Unit raise Refused
  fn stop(Self) -> Unit raise Refused
  fn write(Self, String) -> Unit raise Refused
  fn flush(Self) -> Unit raise Refused
  fn size(Self) -> @geom.Size raise Refused
  fn poll(Self, Int32) -> Bytes raise Refused
  fn now(Self) -> Int32
}

///|
pub extend Refused with Debug::{to_repr}
