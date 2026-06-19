//! System-level operations for Jules OS.
//! Provides safe wrappers for reading/writing procfs, sysfs,
//! kernel info, and hardware detection.

use std::collections::HashMap;
use std::fs;
use std::io::{self, BufRead};
use std::path::Path;

/// Get the kernel release string via procfs.
pub fn get_kernel_release() -> String {
    fs::read_to_string("/proc/sys/kernel/osrelease")
        .map_or_else(|_| "unknown".to_string(), |s| s.trim().to_string())
}

/// Parse /proc/meminfo into a `HashMap` of key → value (in bytes).
///
/// Values in /proc/meminfo are in kB, so we multiply by 1024.
pub fn get_mem_info() -> HashMap<String, u64> {
    let mut mem_data = HashMap::new();

    let Ok(file) = fs::File::open("/proc/meminfo") else {
        return mem_data;
    };

    let reader = io::BufReader::new(file);
    for line in reader.lines() {
        let Ok(line) = line else { continue };

        if let Some(colon_pos) = line.find(':') {
            let key = line[..colon_pos].trim().to_string();
            let val_str = &line[colon_pos + 1..];

            // Extract numeric value (strip " kB" suffix)
            let val_str = val_str.trim();
            let numeric_str = if let Some(kb_pos) = val_str.find(" kB") {
                &val_str[..kb_pos]
            } else {
                val_str
            };

            if let Ok(value) = numeric_str.trim().parse::<u64>() {
                // /proc/meminfo values are in kB
                mem_data.insert(key, value * 1024);
            }
        }
    }

    mem_data
}

/// Get disk usage information for a given path.
///
/// Returns (total, used, available, `usage_percent`) in bytes.
#[allow(clippy::unnecessary_cast)]
pub fn get_disk_usage(path: &str) -> Option<(u64, u64, u64, f64)> {
    let Ok(stat) = nix::sys::statvfs::statvfs(path) else {
        return None;
    };

    let total = stat.blocks() as u64 * stat.fragment_size() as u64;
    let free = stat.blocks_free() as u64 * stat.fragment_size() as u64;
    let available = stat.blocks_available() as u64 * stat.fragment_size() as u64;
    let used = total - free;
    let usage_pct = if total > 0 {
        (used as f64) * 100.0 / (total as f64)
    } else {
        0.0
    };

    Some((total, used, available, usage_pct))
}

/// Get system uptime from /proc/uptime.
///
/// Returns (days, hours, minutes).
pub fn get_uptime() -> Option<(u64, u64, u64)> {
    let content = fs::read_to_string("/proc/uptime").ok()?;
    let seconds: f64 = content.split_whitespace().next()?.parse().ok()?;
    let total_secs = seconds as u64;

    let days = total_secs / 86400;
    let hours = (total_secs % 86400) / 3600;
    let minutes = (total_secs % 3600) / 60;

    Some((days, hours, minutes))
}

/// Write a value to a sysfs/procfs path.
///
/// Silently fails if the path doesn't exist or isn't writable.
pub fn write_sysfs(path: &str, value: &str) {
    let _ = fs::write(path, format!("{value}\n"));
}

/// Format a byte count into a human-readable string.
///
/// Uses binary prefixes (KiB, MiB, GiB, TiB).
pub fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KiB", "MiB", "GiB", "TiB"];
    let mut size = bytes as f64;
    let mut unit_idx = 0;

    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }

    format!("{size:.1}{}", UNITS[unit_idx])
}

/// Find the first existing executable in a list of paths.
///
/// Falls back to the basename if none found.
pub fn find_executable(candidates: &[&str], fallback: &str) -> String {
    for path in candidates {
        if Path::new(path).exists() {
            return path.to_string();
        }
    }
    fallback.to_string()
}

/// Get the current working directory as a string.
pub fn get_cwd() -> String {
    std::env::current_dir().map_or_else(|_| "/".to_string(), |p| p.to_string_lossy().into_owned())
}

// ── Unit Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(0), "0.0B");
        assert_eq!(format_bytes(1023), "1023.0B");
        assert_eq!(format_bytes(1024), "1.0KiB");
        assert_eq!(format_bytes(1536), "1.5KiB");
        assert_eq!(format_bytes(1_048_576), "1.0MiB");
        assert_eq!(format_bytes(1_073_741_824), "1.0GiB");
        assert_eq!(format_bytes(1_099_511_627_776), "1.0TiB");
    }

    #[test]
    fn test_get_kernel_release() {
        let release = get_kernel_release();
        assert!(!release.is_empty());
    }

    #[test]
    fn test_find_executable_fallback() {
        let result = find_executable(&["/nonexistent/path"], "fallback");
        assert_eq!(result, "fallback");
    }

    #[test]
    fn test_get_cwd() {
        let cwd = get_cwd();
        assert!(!cwd.is_empty());
    }
}
