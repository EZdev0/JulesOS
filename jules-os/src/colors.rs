//! ANSI color constants and formatting utilities for Jules OS.
//!
//! Provides a centralized color system used consistently across
//! the entire shell. All color output goes through these constants.

/// ANSI escape code constants.
/// Using `&str` constants instead of heap-allocated `String`s
/// for zero-allocation colored output.
pub const RESET: &str = "\x1b[0m";
pub const BOLD: &str = "\x1b[1m";

// Standard colors
pub const RED: &str = "\x1b[31m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const BLUE: &str = "\x1b[34m";
pub const MAGENTA: &str = "\x1b[35m";
pub const CYAN: &str = "\x1b[36m";

/// Print an error message to stderr.
#[inline]
pub fn print_error(text: &str) {
    eprintln!("{RED}{BOLD}[ERROR]{RESET} {text}");
}
