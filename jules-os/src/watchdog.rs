use crate::colors::{RED, RESET, YELLOW};
use crate::system;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::thread;
use std::time::Duration;

pub fn start_watchdog() {
    println!("{YELLOW}[Watchdog] Starting OS health and hardware watchdog...{RESET}");

    thread::spawn(|| {
        loop {
            thread::sleep(Duration::from_secs(10));

            // 1. Füttere den Kernel/Hardware Watchdog (falls /dev/watchdog existiert)
            if let Ok(mut file) = OpenOptions::new().write(true).open("/dev/watchdog") {
                let _ = file.write_all(b"1\n");
            }

            // 2. OS RAM & Memory Leak Check
            let mem = system::get_mem_info();
            if let (Some(total), Some(avail)) = (mem.get("MemTotal"), mem.get("MemAvailable")) {
                if *total > 0 {
                    let percent_avail = (*avail as f64 / *total as f64) * 100.0;
                    if percent_avail < 10.0 {
                        println!("\n{RED}[OS WATCHDOG] CRITICAL: Memory Leak detected! Very low RAM available ({percent_avail:.1}%){RESET}");
                    }
                }
            }

            // 3. Zombie Process Analysis (PID 1 Responsibilities)
            let mut zombies = 0;
            if let Ok(entries) = fs::read_dir("/proc") {
                for entry in entries.flatten() {
                    let file_name = entry.file_name();
                    if file_name.to_string_lossy().chars().all(char::is_numeric) {
                        let stat_path = format!("/proc/{}/stat", file_name.to_string_lossy());
                        if let Ok(stat) = fs::read_to_string(&stat_path) {
                            let parts: Vec<&str> = stat.split_whitespace().collect();
                            if parts.len() > 2 && parts[2] == "Z" {
                                zombies += 1;
                            }
                        }
                    }
                }
            }

            if zombies > 5 {
                println!("\n{YELLOW}[OS WATCHDOG] WARNING: Detected {zombies} Zombie processes. PID 1 should reap them!{RESET}");
            }
        }
    });
}
