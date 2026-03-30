#include <cctype>
#include <vector>
#include "commands.h"
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/utsname.h>
#include <sys/sysinfo.h>
#include <sys/statvfs.h>
#include <glob.h>
#include <cmath>
#include <cstring>
#include <sstream>
#include <iomanip>
#include <map>

namespace JulesOS {

const std::string COLOR_RESET = "\033[0m";
const std::string COLOR_RED = "\033[31m";
const std::string COLOR_GREEN = "\033[32m";
const std::string COLOR_YELLOW = "\033[33m";
const std::string COLOR_BLUE = "\033[34m";
const std::string COLOR_MAGENTA = "\033[35m";
const std::string COLOR_CYAN = "\033[36m";
const std::string BOLD = "\033[1m";

std::string trim(const std::string& s) {
    std::string trimmed = s;
    size_t first = trimmed.find_first_not_of(" \t\n\r");
    if (std::string::npos == first) return "";
    size_t last = trimmed.find_last_not_of(" \t\n\r");
    return trimmed.substr(first, (last - first + 1));
}

std::string format_bytes(unsigned long bytes) {
    const char* units[] = {"B", "KiB", "MiB", "GiB", "TiB"};
    double size = static_cast<double>(bytes);
    int i = 0;
    while (size >= 1024 && i < 4) {
        size /= 1024;
        i++;
    }
    std::stringstream ss;
    ss << std::fixed << std::setprecision(1) << size << units[i];
    return ss.str();
}

std::map<std::string, unsigned long> get_mem_info() {
    std::map<std::string, unsigned long> mem_data;
    std::ifstream meminfo("/proc/meminfo");
    if (!meminfo.is_open()) return mem_data;

    std::string line;
    while (std::getline(meminfo, line)) {
        size_t colon = line.find(':');
        if (colon != std::string::npos) {
            std::string key = line.substr(0, colon);
            std::string val_str = line.substr(colon + 1);
            size_t start = val_str.find_first_not_of(" ");
            size_t end = val_str.find(" kB");
            if (start != std::string::npos && end != std::string::npos) {
                try {
                    unsigned long value = std::stoul(val_str.substr(start, end - start));
                    mem_data[key] = value * 1024; // convert kB to bytes
                } catch (...) {}
            }
        }
    }
    return mem_data;
}

void execute_external(const std::string& cmd); // forward declaration

void show_help() {
    std::cout << COLOR_CYAN << BOLD << "\n=== Jules OS Core Commands ===\n" << COLOR_RESET;
    std::cout << COLOR_YELLOW << "help" << COLOR_RESET << "      - Show this message\n";
    std::cout << COLOR_YELLOW << "status" << COLOR_RESET << "    - Show system memory, CPU, and OverlayFS usage\n";
    std::cout << COLOR_YELLOW << "boost" << COLOR_RESET << "     - Maximize performance (RAM, CPU, I/O)\n";
    std::cout << COLOR_YELLOW << "fetch" << COLOR_RESET << "     - Display system info beautifully\n";
    std::cout << COLOR_YELLOW << "python" << COLOR_RESET << "    - Enter the Python Interactive Shell\n";
    std::cout << COLOR_YELLOW << "jupdate" << COLOR_RESET << "   - OTA update system core (Phase 2)\n";
    std::cout << COLOR_YELLOW << "clear" << COLOR_RESET << "     - Clear the screen\n";
    std::cout << COLOR_YELLOW << "reboot" << COLOR_RESET << "    - Instantly reboot (restores immutable state)\n";
    std::cout << COLOR_YELLOW << "poweroff" << COLOR_RESET << "  - Shutdown the OS\n";
    std::cout << "Or type any standard Linux command (ls, cd, apk, etc.)\n\n";
}







std::string format_size(unsigned long long bytes) {
    const char* units[] = {"B", "K", "M", "G", "T"};
    int i = 0;
    double size = bytes;
    while (size >= 1024 && i < 4) {
        size /= 1024;
        i++;
    }
    std::stringstream ss;
    ss << std::fixed << std::setprecision(1) << size << units[i];
    return ss.str();
}

void print_disk_usage(const std::string& path) {
    struct statvfs vfs;
    if (statvfs(path.c_str(), &vfs) == 0) {
        unsigned long long total = (unsigned long long)vfs.f_blocks * vfs.f_frsize;
        unsigned long long free = (unsigned long long)vfs.f_bfree * vfs.f_frsize;
        unsigned long long available = (unsigned long long)vfs.f_bavail * vfs.f_frsize;
        unsigned long long used = total - free;
        double usage_pct = (total > 0) ? (double)used * 100.0 / total : 0;

        std::cout << std::left << std::setw(10) << path
                  << std::right << std::setw(8) << format_size(total)
                  << std::setw(8) << format_size(used)
                  << std::setw(8) << format_size(available)
                  << std::setw(6) << (int)std::round(usage_pct) << "%\n";
    }
}

void show_status() {
    std::cout << COLOR_BLUE << BOLD << "\n--- System Status ---\n" << COLOR_RESET;
    std::cout << COLOR_GREEN << "Memory Usage:" << COLOR_RESET << "\n";
    std::map<std::string, unsigned long> mem_info = get_mem_info();
    if (!mem_info.empty()) {
        unsigned long total = mem_info["MemTotal"];
        unsigned long free = mem_info["MemFree"];
        unsigned long buffers = mem_info["Buffers"];
        unsigned long cached = mem_info["Cached"];
        unsigned long slab = mem_info["Slab"];
        unsigned long shared = mem_info["Shmem"];
        unsigned long buff_cache = buffers + cached + slab;
        unsigned long used = total - free - buff_cache;
        unsigned long available = mem_info["MemAvailable"];
        if (available == 0) available = free + buff_cache; // Fallback

        std::cout << "               total        used        free      shared  buff/cache   available\n";
        std::cout << "Mem:    ";
        std::cout << std::setw(12) << format_bytes(total);
        std::cout << std::setw(12) << format_bytes(used);
        std::cout << std::setw(12) << format_bytes(free);
        std::cout << std::setw(12) << format_bytes(shared);
        std::cout << std::setw(12) << format_bytes(buff_cache);
        std::cout << std::setw(12) << format_bytes(available) << "\n";
    } else {
        execute_external("free -h");
    }
    std::cout << COLOR_GREEN << "\nDisk Usage (Immutable Core & Vault):" << COLOR_RESET << "\n";
    std::cout << std::left << std::setw(10) << "Filesystem"
              << std::right << std::setw(8) << "Size"
              << std::setw(8) << "Used"
              << std::setw(8) << "Avail"
              << std::setw(6) << "Use%\n";
    print_disk_usage("/");
    print_disk_usage("/home");
    std::cout << COLOR_GREEN << "\nKernel Version:" << COLOR_RESET << "\n" << get_kernel_release() << "\n" << std::endl;
}

void run_fetch() {
    std::cout << COLOR_CYAN << BOLD << "\n" << R"(
       __      __             ____  _____
      / /_  __/ /__  _____   / __ \/ ___/
 __  / / / / / / _ \/ ___/  / / / /\__ \
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /
\____/\__,_/_/\___/____/   \____//____/
)" << COLOR_RESET;
    std::cout << COLOR_YELLOW << "OS: " << COLOR_RESET << "Jules OS 1.0.0 (Immutable Core)\n";
    std::cout << COLOR_YELLOW << "Kernel: " << COLOR_RESET << get_kernel_release() << "\n";
    std::cout << COLOR_YELLOW << "Shell: " << COLOR_RESET << "Jules Shell (C++)\n";
    struct sysinfo info;
    std::map<std::string, unsigned long> mem_info = get_mem_info();
    if (sysinfo(&info) == 0 && !mem_info.empty()) {
        long uptime = info.uptime;
        long days = uptime / 86400;
        long hours = (uptime % 86400) / 3600;
        long minutes = (uptime % 3600) / 60;
        std::cout << COLOR_YELLOW << "Uptime: " << COLOR_RESET;
        if (days > 0) std::cout << days << " days, ";
        if (hours > 0) std::cout << hours << " hours, ";
        std::cout << minutes << " minutes\n";

        unsigned long total = mem_info["MemTotal"];
        unsigned long free = mem_info["MemFree"];
        unsigned long buffers = mem_info["Buffers"];
        unsigned long cached = mem_info["Cached"];
        unsigned long slab = mem_info["Slab"];
        unsigned long used = total - free - (buffers + cached + slab);

        unsigned long used_mb = used / (1024 * 1024);
        unsigned long total_mb = total / (1024 * 1024);
        double pct = (total > 0) ? (static_cast<double>(used) * 100.0 / total) : 0.0;
        std::cout << COLOR_YELLOW << "Memory: " << COLOR_RESET << used_mb << "/" << total_mb << "MB ("
                  << std::fixed << std::setprecision(2) << pct << "%)\n";
    } else {
        std::cout << COLOR_YELLOW << "Uptime: " << COLOR_RESET; fflush(stdout); execute_external("uptime -p");
        std::cout << COLOR_YELLOW << "Memory: " << COLOR_RESET; fflush(stdout); execute_external("sh -c 'free -m | awk \"NR==2{printf \\\"%s/%sMB (%.2f%%)\\\\n\\\", \\$3,\\$2,\\$3*100/\\$2 }\"'");
    }
    std::cout << COLOR_GREEN << "------------------------------------------\n" << COLOR_RESET << std::endl;
}

void write_sysfs(const std::string& path, const std::string& value) {
    std::ofstream fs(path);
    if (fs.is_open()) {
        fs << value << "\n";
        fs.close();
    }
}

void run_boost() {
    std::cout << COLOR_MAGENTA << BOLD << "\n[+] Initiating Jules Boost Sequence (ULTRA)...\n" << COLOR_RESET;

    std::cout << COLOR_YELLOW << "-> Flushing PageCache, dentries, and inodes..." << COLOR_RESET << "\n";
    sync();
    write_sysfs("/proc/sys/vm/drop_caches", "3");

    std::cout << COLOR_YELLOW << "-> Optimizing Virtual Memory (Swappiness & Overcommit)..." << COLOR_RESET << "\n";
    write_sysfs("/proc/sys/vm/swappiness", "10");
    write_sysfs("/proc/sys/vm/overcommit_memory", "1");

    std::cout << COLOR_YELLOW << "-> Forcing Performance CPU Governor..." << COLOR_RESET << "\n";
    glob_t g;
    if (glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor", 0, nullptr, &g) == 0) {
        for (size_t i = 0; i < g.gl_pathc; ++i) {
            write_sysfs(g.gl_pathv[i], "performance");
        }
        globfree(&g);
    }

    std::cout << COLOR_YELLOW << "-> Disabling Transparent Hugepages (Lower Latency)..." << COLOR_RESET << "\n";
    write_sysfs("/sys/kernel/mm/transparent_hugepage/enabled", "never");

    std::cout << COLOR_GREEN << BOLD << "[OK] System optimized for maximum performance.\n" << COLOR_RESET << std::endl;
}

void run_python() {
    std::cout << COLOR_CYAN << "Starting Python Environment...\n" << COLOR_RESET;

    std::string python_path;
    if (access("/usr/bin/python3", X_OK) == 0) {
        python_path = "/usr/bin/python3";
    } else if (access("/bin/python3", X_OK) == 0) {
        python_path = "/bin/python3";
    } else {
        std::cout << COLOR_YELLOW << "Python3 is not installed. Installing via apk...\n" << COLOR_RESET;
        // On Jules OS (Alpine), apk is usually at /sbin/apk or /usr/bin/apk
        // We'll try to find it via PATH for installation only, or assume a likely path
        execute_external("apk add --no-cache python3");

        // After install, re-check paths
        if (access("/usr/bin/python3", X_OK) == 0) python_path = "/usr/bin/python3";
        else if (access("/bin/python3", X_OK) == 0) python_path = "/bin/python3";
        else {
            std::cerr << COLOR_RED << "Failed to install Python3 or find it after installation." << COLOR_RESET << std::endl;
            return;
        }
    }

    execute_external(python_path);
}

void run_jupdate() {
    std::cout << COLOR_MAGENTA << BOLD << "\n[+] Jules OS System Update...\n" << COLOR_RESET;
    std::cout << COLOR_CYAN << "Checking connection..." << COLOR_RESET << "\n";

    std::string apk_path = "apk";
    if (access("/sbin/apk", X_OK) == 0) apk_path = "/sbin/apk";
    else if (access("/usr/bin/apk", X_OK) == 0) apk_path = "/usr/bin/apk";

    // We skip the ping check with system() and directly attempt apk update
    std::cout << COLOR_YELLOW << "-> Updating package lists..." << COLOR_RESET << "\n";
    execute_external(apk_path + " update");

    std::cout << COLOR_YELLOW << "-> Upgrading system packages..." << COLOR_RESET << "\n";
    execute_external(apk_path + " upgrade");

    std::cout << COLOR_BLUE << "Info: Jules OS user packages have been updated." << COLOR_RESET << "\n\n";
}

void run_clear() {
    std::cout << "\033[2J\033[1;1H";
}

std::string get_kernel_release() {
    struct utsname buffer;
    if (uname(&buffer) == 0) {
        return buffer.release;
    }
    return "unknown";
}

void execute_external(const std::string& cmd) {
    if (cmd.rfind("cd ", 0) == 0) {
        std::string dir = trim(cmd.substr(3));
        if (dir == "~" || dir == "") {
            const char* home = getenv("HOME");
            if (home) dir = home;
            else dir = "/home/jules";
        }
        if (chdir(dir.c_str()) != 0) {
            std::cerr << COLOR_RED << "cd: " << dir << ": No such file or directory" << COLOR_RESET << std::endl;
        }
        return;
    }

    std::vector<std::string> args;
    std::string current;
    bool in_quotes = false;
    char quote_char = '\0';

    for (size_t i = 0; i < cmd.length(); ++i) {
        char c = cmd[i];
        if (in_quotes) {
            if (c == quote_char) {
                in_quotes = false;
                if (current.empty()) {
                    args.push_back(""); // handle empty strings like ""
                }
            } else {
                current += c;
            }
        } else {
            if (c == '"' || c == '\'') {
                in_quotes = true;
                quote_char = c;
            } else if (std::isspace(c)) {
                if (!current.empty() || (i > 0 && (cmd[i-1] == '"' || cmd[i-1] == '\''))) {
                    if (!current.empty()) args.push_back(current);
                    current.clear();
                }
            } else {
                current += c;
            }
        }
    }
    if (!current.empty()) {
        args.push_back(current);
    }

    if (args.empty()) return;

    std::vector<char*> c_args;
    c_args.reserve(args.size() + 1);
    for (auto& arg : args) c_args.push_back(&arg[0]);
    c_args.push_back(nullptr);

    pid_t pid = fork();
    if (pid == -1) {
        std::cerr << COLOR_RED << "Failed to fork" << COLOR_RESET << std::endl;
    } else if (pid == 0) {
        execvp(c_args[0], c_args.data());
        std::cerr << COLOR_RED << "Failed to execute: " << c_args[0] << COLOR_RESET << std::endl;
        exit(127);
    } else {
        int status;
        waitpid(pid, &status, 0);
    }
}

void execute_command(const std::string& cmd) {
    std::string trimmed = trim(cmd);

    if (trimmed.empty()) return;

    if (trimmed == "help") {
        show_help();
    } else if (trimmed == "status") {
        show_status();
    } else if (trimmed == "boost") {
        run_boost();
    } else if (trimmed == "fetch") {
        run_fetch();
    } else if (trimmed == "python") {
        run_python();
    } else if (trimmed == "jupdate" || trimmed == "update") {
        run_jupdate();
    } else if (trimmed == "clear") {
        run_clear();
    } else if (trimmed == "exit" || trimmed == "poweroff") {
        std::cout << COLOR_RED << "Shutting down Jules OS...\n" << COLOR_RESET;
        // Search for absolute poweroff path to prevent hijacking
        std::string poweroff_path;
        if (access("/sbin/poweroff", X_OK) == 0) poweroff_path = "/sbin/poweroff";
        else if (access("/usr/sbin/poweroff", X_OK) == 0) poweroff_path = "/usr/sbin/poweroff";
        else poweroff_path = "poweroff"; // Fallback to PATH as last resort

        execute_external(poweroff_path);

        exit(0);
    } else if (trimmed == "reboot") {
        std::cout << COLOR_YELLOW << "Rebooting Jules OS...\n" << COLOR_RESET;
        std::string reboot_path;
        if (access("/sbin/reboot", X_OK) == 0) reboot_path = "/sbin/reboot";
        else if (access("/usr/sbin/reboot", X_OK) == 0) reboot_path = "/usr/sbin/reboot";
        else reboot_path = "reboot"; // Fallback to PATH as last resort

        execute_external(reboot_path);
        exit(0);
    } else {
        execute_external(trimmed);
    }
}

} // namespace JulesOS
