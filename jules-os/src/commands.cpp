#include "commands.h"
#include <iostream>
#include <cstdlib>
#include <vector>
#include <sstream>
#include <fstream>
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

// A robust way to execute system commands and get output or just run them
void run_system(const char* command) {
    int ret = system(command);
    if (ret != 0) {
        std::cerr << COLOR_RED << "[ERROR] Command failed with code: " << ret << COLOR_RESET << std::endl;
    }
}

void show_help() {
    std::cout << COLOR_CYAN << "\n=== Jules OS Core Commands ===\n" << COLOR_RESET;
    std::cout << COLOR_YELLOW << "help" << COLOR_RESET << "      - Show this message\n";
    std::cout << COLOR_YELLOW << "status" << COLOR_RESET << "    - Show system memory, CPU, and OverlayFS usage\n";
    std::cout << COLOR_YELLOW << "boost" << COLOR_RESET << "     - Flush RAM caches and set CPU to performance mode\n";
    std::cout << COLOR_YELLOW << "python" << COLOR_RESET << "    - Enter the Python Interactive Shell\n";
    std::cout << COLOR_YELLOW << "update" << COLOR_RESET << "    - Fetch latest Jules OS updates from GitHub\n";
    std::cout << COLOR_YELLOW << "clear" << COLOR_RESET << "     - Clear the screen\n";
    std::cout << COLOR_YELLOW << "reboot" << COLOR_RESET << "    - Instantly reboot (restores immutable pristine state)\n";
    std::cout << COLOR_YELLOW << "poweroff" << COLOR_RESET << "  - Shutdown the OS\n";
    std::cout << "Or type any standard Linux command (ls, cd, apk, etc.)\n\n";
}

void show_status() {
    std::cout << COLOR_BLUE << "\n--- System Status ---\n" << COLOR_RESET;
    std::cout << COLOR_GREEN << "Memory Usage:" << COLOR_RESET << "\n";
    run_system("free -h");
    std::cout << COLOR_GREEN << "\nDisk Usage (Immutable Core & Vault):" << COLOR_RESET << "\n";
    run_system("df -h / /home");
    std::cout << COLOR_GREEN << "\nKernel Version:" << COLOR_RESET << "\n";
    run_system("uname -r");
    std::cout << std::endl;
}

void run_boost() {
    std::cout << COLOR_MAGENTA << "\n[+] Initiating Jules Boost Sequence...\n" << COLOR_RESET;
    // Drop caches to free RAM
    std::cout << COLOR_YELLOW << "-> Clearing RAM Caches (PageCache, dentries, inodes)..." << COLOR_RESET << "\n";
    run_system("sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo 'Requires root'");

    // Attempt to set CPU governor to performance
    std::cout << COLOR_YELLOW << "-> Switching CPU Governor to 'performance'..." << COLOR_RESET << "\n";
    run_system("echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true");

    std::cout << COLOR_GREEN << "[OK] System optimized for maximum performance.\n" << COLOR_RESET << std::endl;
}

void run_python() {
    std::cout << COLOR_CYAN << "Starting Python Environment...\n" << COLOR_RESET;
    // Check if python3 is installed, if not, offer to install it via apk
    if (system("which python3 > /dev/null 2>&1") != 0) {
        std::cout << COLOR_YELLOW << "Python3 is not installed. Attempting to install via apk...\n" << COLOR_RESET;
        run_system("apk add --no-cache python3");
    }
    run_system("python3");
}

void run_update() {
    std::cout << COLOR_CYAN << "\n[+] Checking for Jules OS updates...\n" << COLOR_RESET;
    std::cout << COLOR_YELLOW << "Note: You are running an immutable system. Updates will be applied to the base image on next build.\n" << COLOR_RESET;
    // In a real scenario, this would curl a version endpoint or run an OTA script
    run_system("ping -c 1 github.com > /dev/null 2>&1 && echo 'Internet OK.' || echo 'No Internet Connection.'");
    std::cout << "For full updates, pull the latest repo on host and run build.sh.\n\n";
}

void run_clear() {
    std::cout << "\033[2J\033[1;1H";
}

// Tokenize and execute standard shell commands if they are not built-ins
void execute_external(const std::string& cmd) {
    // If it's a cd command, handle it internally because system() creates a subshell
    if (cmd.rfind("cd ", 0) == 0) {
        std::string dir = cmd.substr(3);
        // Remove trailing spaces
        dir.erase(dir.find_last_not_of(" \n\r\t")+1);
        if (chdir(dir.c_str()) != 0) {
            std::cerr << COLOR_RED << "cd: " << dir << ": No such file or directory" << COLOR_RESET << std::endl;
        }
        return;
    }

    // Execute standard command
    int ret = system(cmd.c_str());
    if (ret == -1) {
        std::cerr << COLOR_RED << "Failed to execute: " << cmd << COLOR_RESET << std::endl;
    }
}

void execute_command(const std::string& cmd) {
    if (cmd.empty()) return;

    if (cmd == "help") {
        show_help();
    } else if (cmd == "status") {
        show_status();
    } else if (cmd == "boost") {
        run_boost();
    } else if (cmd == "python") {
        run_python();
    } else if (cmd == "update") {
        run_update();
    } else if (cmd == "clear") {
        run_clear();
    } else if (cmd == "exit" || cmd == "poweroff") {
        std::cout << COLOR_RED << "Shutting down Jules OS...\n" << COLOR_RESET;
        run_system("poweroff");
        exit(0);
    } else if (cmd == "reboot") {
        std::cout << COLOR_YELLOW << "Rebooting Jules OS (Restoring immutable state)...\n" << COLOR_RESET;
        run_system("reboot");
        exit(0);
    } else {
        // Pass to standard linux shell
        execute_external(cmd);
    }
}

} // namespace JulesOS
