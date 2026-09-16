// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The five things a terminal UI cannot do without the operating system: switch
// raw mode, write, read what has arrived, ask for the size, and read a clock.
// Everything else in moonetui is pure MoonBit.

#include <stdint.h>
#include <string.h>
#include <moonbit.h>

#ifdef _WIN32

#include <windows.h>

static DWORD saved_in_mode = 0;
static DWORD saved_out_mode = 0;
static int saved = 0;

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_raw(int32_t on) {
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  if (in == INVALID_HANDLE_VALUE || out == INVALID_HANDLE_VALUE) {
    return -1;
  }
  if (on) {
    if (!saved) {
      if (!GetConsoleMode(in, &saved_in_mode) ||
          !GetConsoleMode(out, &saved_out_mode)) {
        return -1;
      }
      saved = 1;
    }
    // Virtual terminal input makes the console send the same escape sequences a
    // Unix terminal does, which is what lets one parser serve both.
    DWORD in_mode = saved_in_mode;
    in_mode &= ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT);
    in_mode |= ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT;
    DWORD out_mode = saved_out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING |
                     DISABLE_NEWLINE_AUTO_RETURN;
    if (!SetConsoleMode(in, in_mode) || !SetConsoleMode(out, out_mode)) {
      return -1;
    }
    return 0;
  }
  if (saved) {
    SetConsoleMode(in, saved_in_mode);
    SetConsoleMode(out, saved_out_mode);
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_write(const uint8_t *text, int32_t len) {
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  DWORD written = 0;
  int32_t at = 0;
  while (at < len) {
    if (!WriteFile(out, text + at, (DWORD)(len - at), &written, NULL)) {
      return -1;
    }
    at += (int32_t)written;
  }
  return at;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_read(uint8_t *buf, int32_t len, int32_t timeout_ms) {
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  DWORD ready = WaitForSingleObject(in, (DWORD)(timeout_ms < 0 ? 0 : timeout_ms));
  if (ready != WAIT_OBJECT_0) {
    return 0;
  }
  DWORD got = 0;
  if (!ReadFile(in, buf, (DWORD)len, &got, NULL)) {
    return -1;
  }
  return (int32_t)got;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_size(int32_t *out) {
  CONSOLE_SCREEN_BUFFER_INFO info;
  HANDLE handle = GetStdHandle(STD_OUTPUT_HANDLE);
  if (!GetConsoleScreenBufferInfo(handle, &info)) {
    return -1;
  }
  out[0] = info.srWindow.Right - info.srWindow.Left + 1;
  out[1] = info.srWindow.Bottom - info.srWindow.Top + 1;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_now(void) {
  return (int32_t)(GetTickCount64() & 0x7fffffff);
}

#else

#include <errno.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

static struct termios saved_termios;
static int saved = 0;

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_raw(int32_t on) {
  if (on) {
    if (!saved) {
      if (tcgetattr(STDIN_FILENO, &saved_termios) != 0) {
        return -1;
      }
      saved = 1;
    }
    struct termios raw = saved_termios;
    // Characters arrive as they are typed, without echo, and without the
    // terminal turning any of them into signals or flow control.
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_iflag &= ~(IXON | IXOFF | ICRNL | INLCR | IGNCR | BRKINT | ISTRIP);
    raw.c_oflag &= ~(OPOST);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    return tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 ? 0 : -1;
  }
  if (saved) {
    return tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios) == 0 ? 0 : -1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_write(const uint8_t *text, int32_t len) {
  int32_t at = 0;
  while (at < len) {
    ssize_t wrote = write(STDOUT_FILENO, text + at, (size_t)(len - at));
    if (wrote < 0) {
      if (errno == EINTR) {
        continue;
      }
      return -1;
    }
    at += (int32_t)wrote;
  }
  return at;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_read(uint8_t *buf, int32_t len, int32_t timeout_ms) {
  struct pollfd waiting;
  waiting.fd = STDIN_FILENO;
  waiting.events = POLLIN;
  waiting.revents = 0;
  int ready = poll(&waiting, 1, timeout_ms < 0 ? 0 : timeout_ms);
  if (ready <= 0) {
    return 0;
  }
  ssize_t got = read(STDIN_FILENO, buf, (size_t)len);
  if (got < 0) {
    return errno == EAGAIN || errno == EINTR ? 0 : -1;
  }
  return (int32_t)got;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_size(int32_t *out) {
  struct winsize size;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) != 0) {
    return -1;
  }
  out[0] = size.ws_col;
  out[1] = size.ws_row;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moonetui_tty_now(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  int64_t ms = (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
  return (int32_t)(ms & 0x7fffffff);
}

#endif
