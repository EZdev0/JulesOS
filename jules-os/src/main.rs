//! Jules OS Shell & Init System
//!
//! This is the main entry point for Jules OS. When running as PID 1 (init),
//! it handles signal management and zombie process reaping. In all modes,
//! it provides an interactive shell with built-in commands.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────┐
//! │         Jules Shell (Rust)       │
//! │  ┌───────────┐  ┌────────────┐  │
//! │  │ Signal    │  │ Interactive│  │
//! │  │ Handler   │  │ REPL Loop  │  │
//! │  │ (SIGCHLD, │  │ (readline, │  │
//! │  │  SIGTERM) │  │  dispatch) │  │
//! │  └───────────┘  └────────────┘  │
//! │  ┌───────────┐  ┌────────────┐  │
//! │  │ Commands  │  │ System     │  │
//! │  │ Module    │  │ Module     │  │
//! │  │ (help,    │  │ (procfs,   │  │
//! │  │  boost..) │  │  sysfs..)  │  │
//! │  └───────────┘  └────────────┘  │
//! └─────────────────────────────────┘
//! ```

mod colors;
mod commands;
mod system;

use colors::*;
use std::io::{self, BufRead, Write};
use std::sync::atomic::{AtomicBool, Ordering};

/// Global shutdown flag, set by signal handlers.
/// Uses `AtomicBool` for lock-free, async-signal-safe access.
static SHUTDOWN_REQUESTED: AtomicBool = AtomicBool::new(false);

/// Install signal handlers required for PID 1 operation.
///
/// - **SIGCHLD**: Reap zombie child processes (critical for init)
/// - **SIGTERM/SIGINT**: Request graceful shutdown
/// - **SIGHUP**: Ignored (PID 1 should not die on terminal hangup)
fn install_signal_handlers() {
    // SIGCHLD: Reap zombies. This is CRITICAL for PID 1.
    // Without this, orphaned processes accumulate as zombies.
    unsafe {
        signal_hook::low_level::register(signal_hook::consts::SIGCHLD, || {
            // Reap all terminated children (non-blocking)
            loop {
                match nix::sys::wait::waitpid(
                    None,
                    Some(nix::sys::wait::WaitPidFlag::WNOHANG),
                ) {
                    Ok(nix::sys::wait::WaitStatus::StillAlive) => break,
                    Ok(_) => continue, // Reaped a zombie, check for more
                    Err(_) => break,   // No more children
                }
            }
        })
        .expect("Failed to register SIGCHLD handler");

        // SIGTERM: Request graceful shutdown
        signal_hook::low_level::register(signal_hook::consts::SIGTERM, || {
            SHUTDOWN_REQUESTED.store(true, Ordering::Relaxed);
        })
        .expect("Failed to register SIGTERM handler");

        // SIGINT: Request graceful shutdown (Ctrl+C)
        signal_hook::low_level::register(signal_hook::consts::SIGINT, || {
            SHUTDOWN_REQUESTED.store(true, Ordering::Relaxed);
        })
        .expect("Failed to register SIGINT handler");
    }

    // SIGHUP: Ignore (PID 1 should survive terminal hangup)
    unsafe {
        libc::signal(libc::SIGHUP, libc::SIG_IGN);
    }
}

/// Print the Jules OS boot banner.
fn print_banner() {
    println!(
        "{CYAN}{BOLD}\
       __      __             ____  _____\n\
      / /_  __/ /__  _____   / __ \\/ ___/\n\
 __  / / / / / / _ \\/ ___/  / / / /\\__ \\\n\
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /\n\
\\____/\\__,_/_/\\___/____/   \\____//____/\n\
\n{RESET}"
    );
    println!(
        "{MAGENTA}{BOLD}    The Immutable, Intelligent, High-Performance Kernel Interface{RESET}"
    );
    println!(
        "{YELLOW}    Type 'help' for built-in commands. Running on: {GREEN}{}{RESET}",
        system::get_kernel_release()
    );
    println!();
}

/// Generate the interactive shell prompt string.
///
/// Shows the current working directory, with /home abbreviated to ~.
fn get_prompt() -> String {
    let cwd = system::get_cwd();
    let display_dir = if cwd.starts_with("/home") {
        format!("~{}", &cwd[5..])
    } else {
        cwd
    };

    format!(
        "{BOLD}{BLUE}╭─({CYAN}jules@os{BLUE})-[{GREEN}{display_dir}{BLUE}]\n╰─{MAGENTA}❯ {RESET}"
    )
}

/// Main entry point.
///
/// Supports three modes:
/// 1. **Non-interactive**: `jules_shell -c "command"` — execute and exit
/// 2. **Direct args**: `jules_shell command arg1 arg2` — execute and exit
/// 3. **Interactive**: `jules_shell` — enter the REPL loop
fn main() {
    // Install PID 1 signal handlers (always, even if not PID 1)
    install_signal_handlers();

    let args: Vec<String> = std::env::args().collect();

    // Mode 1: Non-interactive (-c flag)
    if args.len() >= 3 && args[1] == "-c" {
        commands::execute_command(&args[2]);
        return;
    }

    // Mode 2: Direct arguments
    if args.len() > 1 {
        let cmd = args[1..].join(" ");
        commands::execute_command(&cmd);
        return;
    }

    // Mode 3: Interactive shell (REPL)
    commands::run_clear();
    print_banner();

    let stdin = io::stdin();
    let mut reader = stdin.lock();
    let mut input = String::new();

    loop {
        // Check if shutdown was requested (by signal handler)
        if SHUTDOWN_REQUESTED.load(Ordering::Relaxed) {
            println!(
                "\n{YELLOW}[PID 1] Received shutdown signal. Halting gracefully...{RESET}"
            );
            loop { std::thread::sleep(std::time::Duration::from_secs(60)); }
        }

        // Print prompt
        print!("{}", get_prompt());
        if io::stdout().flush().is_err() {
            println!("\n[PID 1] stdout flush error. Idling...");
            loop { std::thread::sleep(std::time::Duration::from_secs(60)); }
        }

        // Read input
        input.clear();
        match reader.read_line(&mut input) {
            Ok(0) => {
                // EOF (Ctrl+D) or headless mode without a TTY
                println!("\n[PID 1] Shell input closed. Idling to prevent Kernel Panic...");
                loop { std::thread::sleep(std::time::Duration::from_secs(60)); }
            }
            Ok(_) => {
                let trimmed = input.trim();
                if trimmed.is_empty() {
                    continue;
                }
                if trimmed == "exit" {
                    println!("\n[PID 1] Halting system...");
                    loop { std::thread::sleep(std::time::Duration::from_secs(60)); }
                }
                commands::execute_command(trimmed);
            }
            Err(_) => {
                println!("\n[PID 1] Stdin error. Idling...");
                loop { std::thread::sleep(std::time::Duration::from_secs(60)); }
            }
        }
    }
}

// ── Unit Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_prompt_not_empty() {
        let prompt = get_prompt();
        assert!(!prompt.is_empty());
        assert!(prompt.contains("jules@os"));
    }
}
