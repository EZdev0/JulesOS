use std::collections::HashMap;
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

const CPU_LIMIT_PERCENT: f64 = 85.0; // Suspend if usage > 85%
const CHECK_INTERVAL_SECS: u64 = 3;
const COOLDOWN_SECS: u64 = 6; // Keep suspended for 6 seconds

#[derive(Default)]
struct ProcessStats {
    total_time: u64,
}

pub fn start_daemon() {
    println!("[JRD] JulesOS Resource Daemon initialized. Monitoring processes...");
    thread::spawn(|| {
        let mut prev_sys_ticks: u64 = get_system_ticks();
        let mut prev_procs: HashMap<u32, ProcessStats> = HashMap::new();
        let mut suspended_pids: HashMap<u32, u64> = HashMap::new();

        loop {
            thread::sleep(Duration::from_secs(CHECK_INTERVAL_SECS));

            let current_sys_ticks = get_system_ticks();
            let sys_delta = current_sys_ticks.saturating_sub(prev_sys_ticks);
            prev_sys_ticks = current_sys_ticks;

            if sys_delta == 0 {
                continue;
            }

            let num_cores = get_core_count() as f64;
            let mut current_procs: HashMap<u32, ProcessStats> = HashMap::new();

            // Read all PIDs in /proc
            if let Ok(entries) = fs::read_dir("/proc") {
                for entry in entries.flatten() {
                    let file_name = entry.file_name();
                    let pid_str = file_name.to_string_lossy();

                    if let Ok(pid) = pid_str.parse::<u32>() {
                        // Whitelist PID <= 100 (Critical OS / Init)
                        if pid <= 100 {
                            continue;
                        }

                        let proc_ticks = get_process_ticks(pid);
                        current_procs.insert(
                            pid,
                            ProcessStats {
                                total_time: proc_ticks,
                            },
                        );

                        if let Some(prev_stat) = prev_procs.get(&pid) {
                            let proc_delta = proc_ticks.saturating_sub(prev_stat.total_time);
                            let cpu_usage =
                                (proc_delta as f64 / sys_delta as f64) * 100.0 * num_cores;

                            if cpu_usage > CPU_LIMIT_PERCENT {
                                // Freeze the process
                                suspended_pids.entry(pid).or_insert_with(|| {
                                    println!("\n\x1b[1;33m[JRD] Heavy load detected ({}% CPU) on PID {}. Freezing to prevent lag...\x1b[0m", cpu_usage as u32, pid);
                                    let _ = Command::new("kill").arg("-SIGSTOP").arg(pid.to_string()).output();
                                    0
                                });
                            }
                        }
                    }
                }
            }

            // Update previous proc state
            prev_procs = current_procs;

            // Handle suspended processes (cooldown)
            let mut to_resume = Vec::new();
            for (pid, cycles) in &mut suspended_pids {
                *cycles += CHECK_INTERVAL_SECS;
                if *cycles >= COOLDOWN_SECS {
                    to_resume.push(*pid);
                }
            }

            for pid in to_resume {
                println!(
                    "\x1b[1;32m[JRD] Resuming PID {pid} (Cooldown complete).\x1b[0m"
                );
                let _ = Command::new("kill")
                    .arg("-SIGCONT")
                    .arg(pid.to_string())
                    .output();
                suspended_pids.remove(&pid);
            }
        }
    });
}

fn get_system_ticks() -> u64 {
    if let Ok(stat) = fs::read_to_string("/proc/stat") {
        if let Some(line) = stat.lines().next() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 4 && parts[0] == "cpu" {
                let mut total: u64 = 0;
                for p in &parts[1..] {
                    if let Ok(val) = p.parse::<u64>() {
                        total += val;
                    }
                }
                return total;
            }
        }
    }
    0
}

fn get_process_ticks(pid: u32) -> u64 {
    let path = format!("/proc/{pid}/stat");
    if let Ok(stat) = fs::read_to_string(&path) {
        let parts: Vec<&str> = stat.split_whitespace().collect();
        // stat format: utime is 14th (index 13), stime is 15th (index 14)
        if parts.len() >= 15 {
            let utime: u64 = parts[13].parse().unwrap_or(0);
            let stime: u64 = parts[14].parse().unwrap_or(0);
            return utime + stime;
        }
    }
    0
}

fn get_core_count() -> usize {
    if let Ok(cpuinfo) = fs::read_to_string("/proc/cpuinfo") {
        return cpuinfo
            .lines()
            .filter(|l| l.starts_with("processor"))
            .count()
            .max(1);
    }
    1
}
