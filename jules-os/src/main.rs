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
mod jrd;
mod system;
mod watchdog;
mod splash;

use colors::{CYAN, BOLD, RESET, MAGENTA, YELLOW, GREEN, BLUE};
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
                match nix::sys::wait::waitpid(None, Some(nix::sys::wait::WaitPidFlag::WNOHANG)) {
                    Ok(nix::sys::wait::WaitStatus::StillAlive) | Err(_) => break,
                    Ok(_) => (), // Reaped a zombie, check for more
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
    let display_dir = if let Some(stripped) = cwd.strip_prefix("/home") {
        format!("~{stripped}")
    } else {
        cwd
    };

    format!(
        "{BOLD}{BLUE}╭─({CYAN}jules@os{BLUE})-[{GREEN}{display_dir}{BLUE}]\n╰─{MAGENTA}❯ {RESET}"
    )
}

fn setup_crash_handler() {
    std::panic::set_hook(Box::new(|info| {
        let payload = info.payload();
        let msg = match payload.downcast_ref::<&'static str>() {
            Some(s) => *s,
            None => match payload.downcast_ref::<String>() {
                Some(s) => &s[..],
                None => "Box<dyn Any>",
            },
        };

        let location = info
            .location()
            .map_or_else(|| "unknown".to_string(), |l| format!("{}:{}:{}", l.file(), l.line(), l.column()));

        let crash_log = format!(
            "JULES OS CRASH REPORT\n\nError: {msg}\nLocation: {location}\n\nSystem halted to prevent Kernel Panic."
        );

        // Write to Desktop
        let desktop_path = "/home/jules/Desktop";
        let _ = std::fs::create_dir_all(desktop_path);
        let _ = std::fs::write(format!("{desktop_path}/CRASH_REPORT.log"), crash_log);

        // Launch Recovery UI
        println!("\n\n\x1b[1;31m[CRITICAL ERROR] Jules Shell has panicked!\x1b[0m");
        println!("Launching Recovery Interface...");

        let _ = std::process::Command::new("/bin/recovery_ui.sh").status();

        // Hang forever to prevent Kernel Panic
        loop {
            std::thread::sleep(std::time::Duration::from_mins(1));
        }
    }));
}

/// Main entry point.
///
/// Supports three modes:
/// 1. **Non-interactive**: `jules_shell -c "command"` — execute and exit
/// 2. **Direct args**: `jules_shell command arg1 arg2` — execute and exit
/// 3. **Interactive**: `jules_shell` — enter the REPL loop
fn main() {
    setup_crash_handler();
    jrd::start_daemon();
    watchdog::start_watchdog();

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

    // Mode 4: Auto Desktop (Fallback to REPL if it fails)
    if args.contains(&"--auto-desktop".to_string()) {
        commands::run_clear();
        splash::run_splash();
        
        println!("{YELLOW}[PID 1] Attempting Auto-Boot into Wayland Desktop...{RESET}");
        commands::run_desktop();
        println!("{YELLOW}[PID 1] Desktop session ended. Falling back to recovery shell...{RESET}");
    }

    // Mode 3: Interactive shell (REPL)
    commands::run_clear();
    splash::run_splash();
    print_banner();

    let stdin = io::stdin();
    let mut reader = stdin.lock();
    let mut input = String::new();

    loop {
        // Check if shutdown was requested (by signal handler)
        if SHUTDOWN_REQUESTED.load(Ordering::Relaxed) {
            println!("\n{YELLOW}[PID 1] Received shutdown signal. Halting gracefully...{RESET}");
            loop {
                std::thread::sleep(std::time::Duration::from_mins(1));
            }
        }

        // Print prompt
        print!("{}", get_prompt());
        if io::stdout().flush().is_err() {
            println!("\n[PID 1] stdout flush error. Idling...");
            loop {
                std::thread::sleep(std::time::Duration::from_mins(1));
            }
        }

        // Read input
        input.clear();
        match reader.read_line(&mut input) {
            Ok(0) => {
                // EOF (Ctrl+D) or headless mode without a TTY
                println!("\n[PID 1] Shell input closed. Idling to prevent Kernel Panic...");
                loop {
                    std::thread::sleep(std::time::Duration::from_mins(1));
                }
            }
            Ok(_) => {
                let trimmed = input.trim();
                if trimmed.is_empty() {
                    continue;
                }
                if trimmed == "exit" {
                    println!("\n[PID 1] Halting system...");
                    loop {
                        std::thread::sleep(std::time::Duration::from_mins(1));
                    }
                }
                commands::execute_command(trimmed);
            }
            Err(_) => {
                println!("\n[PID 1] Stdin error. Idling...");
                loop {
                    std::thread::sleep(std::time::Duration::from_mins(1));
                }
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
