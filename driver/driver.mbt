// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Something went wrong talking to the terminal.
pub(all) suberror TtyError {
  Io(String)
} derive(Debug)

///|
/// A terminal, as the library needs it.
///
/// `poll` waits *at most* `timeout_ms` and returns whatever has arrived, which
/// may be nothing. A native driver can block for real; a driver running inside
/// a browser or Node cannot block at all and returns immediately from a queue
/// its callbacks filled. Everything above this trait is written to tolerate
/// both, which is what lets one main loop serve every platform.
pub(open) trait Driver {
  /// Switch the terminal into raw mode and whatever else the application needs.
  fn start(Self) -> Unit raise TtyError
  /// Put the terminal back the way it was found.
  fn stop(Self) -> Unit raise TtyError
  fn write(Self, String) -> Unit raise TtyError
  fn flush(Self) -> Unit raise TtyError
  fn size(Self) -> @geom.Size raise TtyError
  fn poll(Self, Int) -> Bytes raise TtyError
  /// Milliseconds from an arbitrary origin. Only differences are used.
  fn now(Self) -> Int
}
