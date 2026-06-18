//! Shell commands for Jules OS.
//!
//! Each command is implemented as a standalone function.
//! The `execute_command` function dispatches based on user input.

use crate::colors::*;
use crate::system;
use std::ffi::CString;
use std::io::{self, Write};

/// Maximum allowed command length to prevent abuse.
const MAX_COMMAND_LENGTH: usize = 4096;

/// Trim whitespace from both ends of a string.
pub fn trim(s: &str) -> &str {
    s.trim()
}

/// Display the help message with all available commands.
pub fn show_help() {
    println!("\n{CYAN}{BOLD}=== Jules OS Core Commands ==={RESET}");
    println!("{YELLOW}help{RESET}      - Show this message");
    println!("{YELLOW}status{RESET}    - Show system memory, CPU, and disk usage");
    println!("{YELLOW}boost{RESET}     - Maximize performance (RAM, CPU, I/O)");
    println!("{YELLOW}fetch{RESET}     - Display system info beautifully");
    println!("{YELLOW}python{RESET}    - Enter the Python Interactive Shell");
    println!("{YELLOW}jupdate{RESET}   - Update system packages");
    println!("{YELLOW}desktop{RESET}   - Launch the JulesOS Wayland Desktop GUI");
    println!("{YELLOW}clear{RESET}     - Clear the screen");
    println!("{YELLOW}reboot{RESET}    - Instantly reboot (restores immutable state)");
    println!("{YELLOW}poweroff{RESET}  - Shutdown the OS");
    println!("Or type any standard Linux command (ls, cd, apk, etc.)\n");
}

/// Display detailed system status: memory, disk, kernel.
pub fn show_status() {
    println!("\n{BLUE}{BOLD}--- System Status ---{RESET}");

    // Memory info
    println!("{GREEN}Memory Usage:{RESET}");
    let mem = system::get_mem_info();
    if !mem.is_empty() {
        let total = *mem.get("MemTotal").unwrap_or(&0);
        let free = *mem.get("MemFree").unwrap_or(&0);
        let buffers = *mem.get("Buffers").unwrap_or(&0);
        let cached = *mem.get("Cached").unwrap_or(&0);
        let slab = *mem.get("Slab").unwrap_or(&0);
        let shared = *mem.get("Shmem").unwrap_or(&0);
        let buff_cache = buffers + cached + slab;
        let used = total.saturating_sub(free).saturating_sub(buff_cache);
        let available = *mem.get("MemAvailable").unwrap_or(&(free + buff_cache));

        println!("               total        used        free      shared  buff/cache   available");
        println!(
            "Mem:    {:>12}{:>12}{:>12}{:>12}{:>12}{:>12}",
            system::format_bytes(total),
            system::format_bytes(used),
            system::format_bytes(free),
            system::format_bytes(shared),
            system::format_bytes(buff_cache),
            system::format_bytes(available),
        );
    } else {
        execute_external("free -h");
    }

    // Disk info
    println!("\n{GREEN}Disk Usage (Immutable Core & Vault):{RESET}");
    println!(
        "{:<10}{:>8}{:>8}{:>8}{:>6}",
        "Filesystem", "Size", "Used", "Avail", "Use%"
    );
    print_disk_usage("/");
    print_disk_usage("/home");

    // Kernel
    println!(
        "\n{GREEN}Kernel Version:{RESET}\n{}\n",
        system::get_kernel_release()
    );
}

/// Print disk usage for a given mount point.
fn print_disk_usage(path: &str) {
    if let Some((total, used, available, usage_pct)) = system::get_disk_usage(path) {
        println!(
            "{:<10}{:>8}{:>8}{:>8}{:>5}%",
            path,
            system::format_bytes(total),
            system::format_bytes(used),
            system::format_bytes(available),
            usage_pct.round() as i64,
        );
    }
}

/// Display a beautiful system info summary (neofetch-style).
pub fn run_fetch() {
    println!(
        "{CYAN}{BOLD}\n\
       __      __             ____  _____\n\
      / /_  __/ /__  _____   / __ \\/ ___/\n\
 __  / / / / / / _ \\/ ___/  / / / /\\__ \\\n\
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /\n\
\\____/\\__,_/_/\\___/____/   \\____//____/\n\
{RESET}"
    );

    println!("{YELLOW}OS:{RESET}      Jules OS 1.0.0 (Immutable Core)");
    println!("{YELLOW}Kernel:{RESET}  {}", system::get_kernel_release());
    println!("{YELLOW}Shell:{RESET}   Jules Shell (Rust)");

    if let Some((days, hours, minutes)) = system::get_uptime() {
        print!("{YELLOW}Uptime:{RESET}  ");
        if days > 0 {
            print!("{days} days, ");
        }
        if hours > 0 {
            print!("{hours} hours, ");
        }
        println!("{minutes} minutes");
    }

    let mem = system::get_mem_info();
    if !mem.is_empty() {
        let total = *mem.get("MemTotal").unwrap_or(&0);
        let free = *mem.get("MemFree").unwrap_or(&0);
        let buffers = *mem.get("Buffers").unwrap_or(&0);
        let cached = *mem.get("Cached").unwrap_or(&0);
        let slab = *mem.get("Slab").unwrap_or(&0);
        let used = total.saturating_sub(free).saturating_sub(buffers + cached + slab);

        let used_mb = used / (1024 * 1024);
        let total_mb = total / (1024 * 1024);
        let pct = if total > 0 {
            (used as f64) * 100.0 / (total as f64)
        } else {
            0.0
        };
        println!("{YELLOW}Memory:{RESET}  {used_mb}/{total_mb}MB ({pct:.2}%)");
    }

    println!("{GREEN}------------------------------------------{RESET}\n");
}

/// Apply performance optimizations (boost mode).
pub fn run_boost() {
    println!("\n{MAGENTA}{BOLD}[+] Initiating Jules Boost Sequence (ULTRA)...{RESET}");

    println!("{YELLOW}-> Flushing PageCache, dentries, and inodes...{RESET}");
    nix::unistd::sync();
    system::write_sysfs("/proc/sys/vm/drop_caches", "3");

    println!("{YELLOW}-> Optimizing Virtual Memory (Swappiness & Overcommit)...{RESET}");
    system::write_sysfs("/proc/sys/vm/swappiness", "10");
    system::write_sysfs("/proc/sys/vm/overcommit_memory", "1");

    println!("{YELLOW}-> Forcing Performance CPU Governor...{RESET}");
    // Find all CPU governor paths using glob pattern
    if let Ok(entries) = std::fs::read_dir("/sys/devices/system/cpu") {
        for entry in entries.flatten() {
            let governor_path = entry.path().join("cpufreq/scaling_governor");
            if governor_path.exists() {
                let _ = std::fs::write(&governor_path, "performance\n");
            }
        }
    }

    println!("{YELLOW}-> Disabling Transparent Hugepages (Lower Latency)...{RESET}");
    system::write_sysfs("/sys/kernel/mm/transparent_hugepage/enabled", "never");

    println!("{GREEN}{BOLD}[OK] System optimized for maximum performance.{RESET}\n");
}

/// Start the Python interactive shell.
pub fn run_python() {
    println!("{CYAN}Starting Python Environment...{RESET}");

    let python_path = system::find_executable(
        &["/usr/bin/python3", "/bin/python3"],
        "",
    );

    if python_path.is_empty() {
        println!("{YELLOW}Python3 is not installed. Installing via apk...{RESET}");
        execute_external("apk add --no-cache python3");

        let python_path = system::find_executable(
            &["/usr/bin/python3", "/bin/python3"],
            "",
        );
        if python_path.is_empty() {
            print_error("Failed to install Python3.");
            return;
        }
        execute_external(&python_path);
    } else {
        execute_external(&python_path);
    }
}

/// Update system packages via apk.
pub fn run_jupdate() {
    println!("\n{MAGENTA}{BOLD}[+] Jules OS System Update...{RESET}");
    println!("{CYAN}Checking connection...{RESET}");

    let apk = system::find_executable(&["/sbin/apk", "/usr/bin/apk"], "apk");

    println!("{YELLOW}-> Updating package lists...{RESET}");
    execute_external(&format!("{apk} update"));

    println!("{YELLOW}-> Upgrading system packages...{RESET}");
    execute_external(&format!("{apk} upgrade"));

    println!("{BLUE}Info: Jules OS user packages have been updated.{RESET}\n");
}

/// Clear the terminal screen.
pub fn run_clear() {
    print!("\x1b[2J\x1b[1;1H");
    let _ = io::stdout().flush();
}

/// Launch the Wayland Desktop Environment (Sway).
pub fn run_desktop() {
    println!("{CYAN}{BOLD}[+] Initializing JulesOS Wayland Desktop...{RESET}");
    
    // Set essential Wayland environment variables
    std::env::set_var("XDG_SESSION_TYPE", "wayland");
    std::env::set_var("XDG_CURRENT_DESKTOP", "sway");
    std::env::set_var("MOZ_ENABLE_WAYLAND", "1"); // For Firefox if installed
    std::env::set_var("WLR_NO_HARDWARE_CURSORS", "1"); // Better VM/QEMU compatibility
    std::env::set_var("XDG_RUNTIME_DIR", "/run/user/1000");

    let sway_path = system::find_executable(&["/usr/bin/sway", "/bin/sway"], "");

    if sway_path.is_empty() {
        print_error("Desktop components not installed! Rebuild ISO with desktop feature.");
        return;
    }

    println!("{YELLOW}-> Starting Sway Compositor...{RESET}");
    execute_external(&sway_path);
    println!("{YELLOW}-> Desktop session ended.{RESET}");
}

/// Execute an external command using fork + execvp.
///
/// This is the core process-spawning mechanism. It:
/// - Handles `cd` as a built-in (changes CWD of shell process)
/// - Forks a child process for everything else
/// - Closes unnecessary FDs in the child (security)
/// - Uses execvp for PATH-based command lookup
pub fn execute_external(cmd: &str) {
    let cmd = cmd.trim();
    if cmd.is_empty() {
        return;
    }

    // Reject excessively long commands
    if cmd.len() > MAX_COMMAND_LENGTH {
        print_error(&format!(
            "Command too long (max {} chars)",
            MAX_COMMAND_LENGTH
        ));
        return;
    }

    // Handle `cd` as a built-in
    if cmd.starts_with("cd ") || cmd == "cd" {
        let dir = if cmd.len() > 3 {
            cmd[3..].trim()
        } else {
            ""
        };
        let target = if dir.is_empty() || dir == "~" {
            std::env::var("HOME").unwrap_or_else(|_| "/home/jules".to_string())
        } else {
            dir.to_string()
        };
        if std::env::set_current_dir(&target).is_err() {
            eprintln!("{RED}cd: {target}: No such file or directory{RESET}");
        }
        return;
    }

    // Parse command into arguments (handles basic quoting)
    let args = parse_command(cmd);
    if args.is_empty() {
        return;
    }

    // Convert to CStrings for execvp
    let c_args: Vec<CString> = match args
        .iter()
        .map(|s| CString::new(s.as_str()))
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(v) => v,
        Err(_) => {
            print_error("Invalid command (contains null bytes)");
            return;
        }
    };

    // Fork and exec
    match unsafe { nix::unistd::fork() } {
        Ok(nix::unistd::ForkResult::Parent { child }) => {
            // Parent: wait for child to complete
            let _ = nix::sys::wait::waitpid(child, None);
        }
        Ok(nix::unistd::ForkResult::Child) => {
            // Child: close unnecessary file descriptors (security hardening)
            close_fds_above(3);

            // Execute the command
            let _ = nix::unistd::execvp(&c_args[0], &c_args);

            // If execvp returns, the command was not found
            eprintln!("{RED}Failed to execute: {}{RESET}", args[0]);
            // Use _exit to avoid flushing parent's buffers
            unsafe { libc::_exit(127) };
        }
        Err(e) => {
            print_error(&format!("Failed to fork: {e}"));
        }
    }
}

/// Parse a command string into a vector of arguments.
///
/// Handles basic single and double quoting.
fn parse_command(cmd: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut in_quotes = false;
    let mut quote_char = '\0';

    for ch in cmd.chars() {
        if in_quotes {
            if ch == quote_char {
                in_quotes = false;
                if current.is_empty() {
                    args.push(String::new()); // Preserve empty quoted strings
                }
            } else {
                current.push(ch);
            }
        } else if ch == '"' || ch == '\'' {
            in_quotes = true;
            quote_char = ch;
        } else if ch.is_whitespace() {
            if !current.is_empty() {
                args.push(std::mem::take(&mut current));
            }
        } else {
            current.push(ch);
        }
    }

    if !current.is_empty() {
        args.push(current);
    }

    args
}

/// Close all file descriptors >= start_fd.
///
/// This prevents leaking open FDs to child processes (security).
fn close_fds_above(start_fd: i32) {
    let max_fd = unsafe { libc::sysconf(libc::_SC_OPEN_MAX) };
    let max_fd = if max_fd < 0 { 1024 } else { max_fd as i32 };

    for fd in start_fd..max_fd {
        unsafe { libc::close(fd) };
    }
}

/// Dispatch a command string to the appropriate handler.
///
/// Built-in commands are handled directly.
/// Everything else is passed to `execute_external`.
pub fn execute_command(cmd: &str) {
    let trimmed = trim(cmd);

    if trimmed.is_empty() {
        return;
    }

    match trimmed {
        "help" => show_help(),
        "status" => show_status(),
        "boost" => run_boost(),
        "fetch" => run_fetch(),
        "desktop" => run_desktop(),
        "python" | "python3" => run_python(),
        "jupdate" | "update" => run_jupdate(),
        "clear" => run_clear(),
        "exit" | "poweroff" => {
            println!("{RED}Shutting down Jules OS...{RESET}");
            let poweroff_path = system::find_executable(
                &["/sbin/poweroff", "/usr/sbin/poweroff"],
                "poweroff",
            );
            execute_external(&poweroff_path);
            std::process::exit(0);
        }
        "reboot" => {
            println!("{YELLOW}Rebooting Jules OS...{RESET}");
            let reboot_path = system::find_executable(
                &["/sbin/reboot", "/usr/sbin/reboot"],
                "reboot",
            );
            execute_external(&reboot_path);
            std::process::exit(0);
        }
        _ => execute_external(trimmed),
    }
}

// ── Unit Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trim() {
        assert_eq!(trim(""), "");
        assert_eq!(trim("  "), "");
        assert_eq!(trim("hello"), "hello");
        assert_eq!(trim("  hello  "), "hello");
        assert_eq!(trim("\t\nhello\r "), "hello");
        assert_eq!(trim("  hello world  "), "hello world");
    }

    #[test]
    fn test_parse_command_simple() {
        let args = parse_command("ls -la /home");
        assert_eq!(args, vec!["ls", "-la", "/home"]);
    }

    #[test]
    fn test_parse_command_quoted() {
        let args = parse_command("echo \"hello world\"");
        assert_eq!(args, vec!["echo", "hello world"]);
    }

    #[test]
    fn test_parse_command_empty() {
        let args = parse_command("");
        assert!(args.is_empty());

        let args = parse_command("   ");
        assert!(args.is_empty());
    }

    #[test]
    fn test_parse_command_single_quotes() {
        let args = parse_command("echo 'hello world'");
        assert_eq!(args, vec!["echo", "hello world"]);
    }
}
