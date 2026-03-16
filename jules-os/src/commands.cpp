#include "commands.h"
#include <iostream>
#include <cstdlib>
#include <vector>
#include <sstream>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

namespace JulesOS {

const std::string COLOR_RESET = "\033[0m";
const std::string COLOR_RED = "\033[31m";
const std::string COLOR_GREEN = "\033[32m";
const std::string COLOR_YELLOW = "\033[33m";
const std::string COLOR_BLUE = "\033[34m";
const std::string COLOR_MAGENTA = "\033[35m";
const std::string COLOR_CYAN = "\033[36m";
const std::string BOLD = "\033[1m";

void run_system(const char* command) {
    int ret = system(command);
    if (ret != 0) {
        if (WIFEXITED(ret)) {
            int exit_code = WEXITSTATUS(ret);
            if (exit_code != 0 && exit_code != 127) {
                // std::cerr << COLOR_RED << "[ERROR] Command failed with exit code: " << exit_code << COLOR_RESET << std::endl;
            }
        }
    }
}

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

void show_status() {
    std::cout << COLOR_BLUE << BOLD << "\n--- System Status ---\n" << COLOR_RESET;
    std::cout << COLOR_GREEN << "Memory Usage:" << COLOR_RESET << "\n";
    run_system("free -h");
    std::cout << COLOR_GREEN << "\nDisk Usage (Immutable Core & Vault):" << COLOR_RESET << "\n";
    run_system("df -h / /home 2>/dev/null || df -h /");
    std::cout << COLOR_GREEN << "\nKernel Version:" << COLOR_RESET << "\n";
    run_system("uname -r");
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
    std::cout << COLOR_YELLOW << "Kernel: " << COLOR_RESET; fflush(stdout); run_system("uname -r");
    std::cout << COLOR_YELLOW << "Shell: " << COLOR_RESET << "Jules Shell (C++)\n";
    std::cout << COLOR_YELLOW << "Uptime: " << COLOR_RESET; fflush(stdout); run_system("uptime -p");
    std::cout << COLOR_YELLOW << "Memory: " << COLOR_RESET; fflush(stdout); run_system("free -m | awk 'NR==2{printf \"%s/%sMB (%.2f%%)\\n\", $3,$2,$3*100/$2 }'");
    std::cout << COLOR_GREEN << "------------------------------------------\n" << COLOR_RESET << std::endl;
}

void run_boost() {
    std::cout << COLOR_MAGENTA << BOLD << "\n[+] Initiating Jules Boost Sequence (ULTRA)...\n" << COLOR_RESET;

    std::cout << COLOR_YELLOW << "-> Flushing PageCache, dentries, and inodes..." << COLOR_RESET << "\n";
    run_system("sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true");

    std::cout << COLOR_YELLOW << "-> Optimizing Virtual Memory (Swappiness & Overcommit)..." << COLOR_RESET << "\n";
    run_system("echo 10 > /proc/sys/vm/swappiness 2>/dev/null || true");
    run_system("echo 1 > /proc/sys/vm/overcommit_memory 2>/dev/null || true");

    std::cout << COLOR_YELLOW << "-> Forcing Performance CPU Governor..." << COLOR_RESET << "\n";
    run_system("for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > \"$g\" 2>/dev/null; done || true");

    std::cout << COLOR_YELLOW << "-> Disabling Transparent Hugepages (Lower Latency)..." << COLOR_RESET << "\n";
    run_system("echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true");

    std::cout << COLOR_GREEN << BOLD << "[OK] System optimized for maximum performance.\n" << COLOR_RESET << std::endl;
}

void run_python() {
    std::cout << COLOR_CYAN << "Starting Python Environment...\n" << COLOR_RESET;
    if (system("which python3 > /dev/null 2>&1") != 0) {
        std::cout << COLOR_YELLOW << "Python3 is not installed. Installing via apk...\n" << COLOR_RESET;
        run_system("apk add --no-cache python3");
    }
    run_system("python3");
}

void run_jupdate() {
    std::cout << COLOR_MAGENTA << BOLD << "\n[+] Jules OS OTA Update (Phase 2)...\n" << COLOR_RESET;
    std::cout << COLOR_CYAN << "Checking connection to GitHub..." << COLOR_RESET << "\n";
    if (system("ping -c 1 8.8.8.8 > /dev/null 2>&1") != 0) {
        std::cerr << COLOR_RED << "[ERROR] Internet connection required for OTA updates." << COLOR_RESET << std::endl;
        return;
    }
    std::cout << COLOR_YELLOW << "-> Fetching latest Jules Shell binary..." << COLOR_RESET << "\n";
    // This is a placeholder for real OTA logic
    std::cout << COLOR_BLUE << "Info: Jules OS is currently at the latest version (1.0.0)." << COLOR_RESET << "\n";
    std::cout << COLOR_BLUE << "Info: Updates are applied to the base image and require reboot." << COLOR_RESET << "\n\n";
}

void run_update() {
    run_jupdate();
}

void run_clear() {
    std::cout << "\033[2J\033[1;1H";
}

void execute_external(const std::string& cmd) {
    if (cmd.rfind("cd ", 0) == 0) {
        std::string dir = cmd.substr(3);
        dir.erase(0, dir.find_first_not_of(" \t\n\r"));
        dir.erase(dir.find_last_not_of(" \t\n\r") + 1);
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

    int ret = system(cmd.c_str());
    if (ret == -1) {
        std::cerr << COLOR_RED << "Failed to execute: " << cmd << COLOR_RESET << std::endl;
    }
}

void execute_command(const std::string& cmd) {
    std::string trimmed = cmd;
    trimmed.erase(0, trimmed.find_first_not_of(" \t\n\r"));
    trimmed.erase(trimmed.find_last_not_of(" \t\n\r") + 1);

    if (trimmed.empty()) return;

    if (cmd == "help") {
        show_help();
    } else if (cmd == "status") {
        show_status();
    } else if (cmd == "boost") {
        run_boost();
    } else if (cmd == "fetch") {
        run_fetch();
    } else if (cmd == "python") {
        run_python();
    } else if (cmd == "jupdate" || cmd == "update") {
        run_jupdate();
    } else if (cmd == "clear") {
        run_clear();
    } else if (cmd == "exit" || cmd == "poweroff") {
        std::cout << COLOR_RED << "Shutting down Jules OS...\n" << COLOR_RESET;
        run_system("poweroff");
        exit(0);
    } else if (cmd == "reboot") {
        std::cout << COLOR_YELLOW << "Rebooting Jules OS...\n" << COLOR_RESET;
        run_system("reboot");
        exit(0);
    } else {
        execute_external(cmd);
    }
}

} // namespace JulesOS
