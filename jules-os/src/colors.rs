#![allow(dead_code)]
//! ANSI color constants and formatting utilities for Jules OS.
//!
//! Provides a centralized color system used consistently across
//! the entire shell. All color output goes through these constants.

/// ANSI escape code constants.
/// Using `&str` constants instead of heap-allocated `String`s
/// for zero-allocation colored output.
pub const RESET: &str = "\x1b[0m";
pub const BOLD: &str = "\x1b[1m";
pub const DIM: &str = "\x1b[2m";

// Standard colors
pub const RED: &str = "\x1b[31m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const BLUE: &str = "\x1b[34m";
pub const MAGENTA: &str = "\x1b[35m";
pub const CYAN: &str = "\x1b[36m";
pub const WHITE: &str = "\x1b[37m";

// Bright colors
pub const BRIGHT_RED: &str = "\x1b[91m";
pub const BRIGHT_GREEN: &str = "\x1b[92m";
pub const BRIGHT_CYAN: &str = "\x1b[96m";

/// Print a colored, bold section header.
#[inline]
pub fn print_header(text: &str) {
    println!("{CYAN}{BOLD}{text}{RESET}");
}

/// Print a success message.
#[inline]
pub fn print_ok(text: &str) {
    println!("{GREEN}{BOLD}[OK]{RESET} {text}");
}

/// Print a warning message.
#[inline]
pub fn print_warn(text: &str) {
    println!("{YELLOW}[WARN]{RESET} {text}");
}

/// Print an error message to stderr.
#[inline]
pub fn print_error(text: &str) {
    eprintln!("{RED}{BOLD}[ERROR]{RESET} {text}");
}
