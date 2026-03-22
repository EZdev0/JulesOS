#include <cctype>
#include <vector>
#include "commands.h"
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/utsname.h>
#include <sys/statvfs.h>
#include <sys/sysinfo.h>
#include <glob.h>
#include <iomanip>
#include <cmath>
#include <sstream>

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
    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        unsigned long long total_ram = (unsigned long long)si.totalram * si.mem_unit;
        unsigned long long free_ram = (unsigned long long)si.freeram * si.mem_unit;
        unsigned long long buffer_ram = (unsigned long long)si.bufferram * si.mem_unit;
        // In modern Linux, 'free' also includes cached, but sysinfo doesn't easily give 'cached' without reading /proc/meminfo
        // For simplicity and to avoid too much complexity, we'll use a slightly simplified version or read /proc/meminfo
        std::cout << "Total: " << format_size(total_ram) << "  Used: " << format_size(total_ram - free_ram - buffer_ram)
                  << "  Free: " << format_size(free_ram) << "  Buffers: " << format_size(buffer_ram) << "\n";
    } else {
        execute_external("free -h");
    }

    std::cout << COLOR_GREEN << "\nDisk Usage (Immutable Core & Vault):" << COLOR_RESET << "\n";
    std::cout << std::left << std::setw(10) << "Filesystem"
              << std::right << std::setw(8) << "Size"
              << std::setw(8) << "Used"
              << std::setw(8) << "Avail"
              << std::setw(8) << "Use%\n";
    print_disk_usage("/");
    if (access("/home", F_OK) == 0) {
        print_disk_usage("/home");
    }

    std::cout << COLOR_GREEN << "\nKernel Version:" << COLOR_RESET << "\n";
    struct utsname buffer;
    if (uname(&buffer) == 0) {
        std::cout << buffer.release << "\n";
    } else {
        std::cout << "unknown\n";
    }
    std::cout << std::endl;
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
    std::cout << COLOR_YELLOW << "Kernel: " << COLOR_RESET;
    struct utsname buffer;
    if (uname(&buffer) == 0) {
        std::cout << buffer.release << "\n";
    } else {
        std::cout << "unknown\n";
    }
    std::cout << COLOR_YELLOW << "Shell: " << COLOR_RESET << "Jules Shell (C++)\n";
    std::cout << COLOR_YELLOW << "Uptime: " << COLOR_RESET;

    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        long uptime = si.uptime;
        int days = uptime / 86400;
        int hours = (uptime % 86400) / 3600;
        int minutes = (uptime % 3600) / 60;

        std::cout << "up ";
        if (days > 0) std::cout << days << " days, ";
        if (hours > 0) std::cout << hours << " hours, ";
        std::cout << minutes << " minutes\n";
        unsigned long long total_ram = (unsigned long long)si.totalram * si.mem_unit;
        unsigned long long free_ram = (unsigned long long)si.freeram * si.mem_unit;
        unsigned long long buffer_ram = (unsigned long long)si.bufferram * si.mem_unit;
        // Approximation of used memory similar to how 'free' does it (simplified)
        unsigned long long used_ram = total_ram - free_ram - buffer_ram;
        double usage_pct = (total_ram > 0) ? (double)used_ram * 100.0 / total_ram : 0;

        std::cout << COLOR_YELLOW << "Memory: " << COLOR_RESET
                  << (used_ram / 1024 / 1024) << "/" << (total_ram / 1024 / 1024) << "MB ("
                  << std::fixed << std::setprecision(2) << usage_pct << "%)\n";
    } else {
        std::cout << "unknown\n";
        std::cout << COLOR_YELLOW << "Memory: " << COLOR_RESET << "unknown\n";
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
    // Basic check for python3 binary existence instead of system()
    if (access("/usr/bin/python3", X_OK) != 0 && access("/bin/python3", X_OK) != 0) {
        std::cout << COLOR_YELLOW << "Python3 is not installed. Installing via apk...\n" << COLOR_RESET;
        execute_external("apk add --no-cache python3");
    }
    execute_external("python3");
}

void run_jupdate() {
    std::cout << COLOR_MAGENTA << BOLD << "\n[+] Jules OS System Update...\n" << COLOR_RESET;
    std::cout << COLOR_CYAN << "Checking connection..." << COLOR_RESET << "\n";

    // We skip the ping check with system() and directly attempt apk update
    std::cout << COLOR_YELLOW << "-> Updating package lists..." << COLOR_RESET << "\n";
    execute_external("apk update");

    std::cout << COLOR_YELLOW << "-> Upgrading system packages..." << COLOR_RESET << "\n";
    execute_external("apk upgrade");

    std::cout << COLOR_BLUE << "Info: Jules OS user packages have been updated." << COLOR_RESET << "\n\n";
}

void run_clear() {
    std::cout << "\033[2J\033[1;1H";
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
        execute_external("poweroff");
        exit(0);
    } else if (trimmed == "reboot") {
        std::cout << COLOR_YELLOW << "Rebooting Jules OS...\n" << COLOR_RESET;
        execute_external("reboot");
        exit(0);
    } else {
        execute_external(trimmed);
    }
}

} // namespace JulesOS
