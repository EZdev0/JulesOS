#include "commands.h"
#include <iostream>
#include <string>
#include <unistd.h>
#include <cstdlib>
#include <vector>
#include <cstring>
#include <csignal>
#include <atomic>
#include <sys/wait.h>
#include <climits>

using namespace JulesOS;

// ── PID 1 Signal Handling ─────────────────────────────────────
// When running as PID 1 (init), the kernel does NOT deliver default
// signal actions. We MUST explicitly handle SIGCHLD (zombie reaping),
// SIGTERM/SIGINT (graceful shutdown), and ignore SIGHUP.

static std::atomic<bool> g_shutdown_requested{false};

/**
 * SIGCHLD handler: Reap all zombie child processes.
 * This is critical for PID 1 – orphaned processes are reparented
 * to PID 1, and we must reap them to prevent zombie accumulation.
 * Only async-signal-safe functions are used here.
 */
static void sigchld_handler(int /*sig*/) {
    int saved_errno = errno;
    while (waitpid(-1, nullptr, WNOHANG) > 0) {
        // Reap all terminated children
    }
    errno = saved_errno;
}

/**
 * SIGTERM/SIGINT handler: Request graceful shutdown.
 * Sets an atomic flag that the main loop checks.
 */
static void shutdown_handler(int /*sig*/) {
    g_shutdown_requested.store(true, std::memory_order_relaxed);
}

/**
 * Install signal handlers required for PID 1 operation.
 * Uses sigaction() instead of signal() for reliable behavior.
 */
static void install_signal_handlers() {
    struct sigaction sa_chld;
    std::memset(&sa_chld, 0, sizeof(sa_chld));
    sa_chld.sa_handler = sigchld_handler;
    sa_chld.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa_chld, nullptr);

    struct sigaction sa_shutdown;
    std::memset(&sa_shutdown, 0, sizeof(sa_shutdown));
    sa_shutdown.sa_handler = shutdown_handler;
    sa_shutdown.sa_flags = 0;
    sigaction(SIGTERM, &sa_shutdown, nullptr);
    sigaction(SIGINT, &sa_shutdown, nullptr);

    // Ignore SIGHUP (terminal hangup) – PID 1 should not die on HUP
    struct sigaction sa_ignore;
    std::memset(&sa_ignore, 0, sizeof(sa_ignore));
    sa_ignore.sa_handler = SIG_IGN;
    sigaction(SIGHUP, &sa_ignore, nullptr);
}

// ── UI Functions ──────────────────────────────────────────────

void print_banner() {
    std::cout << COLOR_CYAN << BOLD << R"(
       __      __             ____  _____
      / /_  __/ /__  _____   / __ \/ ___/
 __  / / / / / / _ \/ ___/  / / / /\__ \
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /
\____/\__,_/_/\___/____/   \____//____/

)" << COLOR_RESET;
    std::cout << COLOR_MAGENTA << BOLD << "    The Immutable, Intelligent, High-Performance Kernel Interface" << COLOR_RESET << "\n";
    std::cout << COLOR_YELLOW << "    Type 'help' for built-in commands. Running on: " << COLOR_GREEN << get_kernel_release() << COLOR_RESET << "\n";
}

std::string get_prompt() {
    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) != nullptr) {
        std::string dir(cwd);
        size_t pos = dir.find("/home");
        if (pos == 0) {
            dir.replace(0, 5, "~");
        }
        return BOLD + COLOR_BLUE + "╭─(" + COLOR_CYAN + "jules@os" + COLOR_BLUE + ")-[" + COLOR_GREEN + dir + COLOR_BLUE + "]\n╰─" + COLOR_MAGENTA + "❯ " + COLOR_RESET;
    }
    return BOLD + COLOR_MAGENTA + "❯ " + COLOR_RESET;
}

// ── Main Entry Point ──────────────────────────────────────────

int main(int argc, const char* argv[]) {
    // Install PID 1 signal handlers (critical for init process)
    install_signal_handlers();

    // Check for -c flag (standard shell behavior)
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-c" && i + 1 < argc) {
            execute_command(argv[i+1]);
            return 0;
        }
    }

    // Handle other arguments as a single command
    if (argc > 1) {
        size_t total_length = 0;
        for (int i = 1; i < argc; ++i) {
            total_length += std::strlen(argv[i]);
        }
        // Only add space separators if there are 2+ arguments
        if (argc > 2) {
            total_length += static_cast<size_t>(argc - 2);
        }

        std::string cmd;
        cmd.reserve(total_length);
        for (int i = 1; i < argc; ++i) {
            cmd += argv[i];
            if (i < argc - 1) cmd += " ";
        }
        execute_command(cmd);
        return 0;
    }

    // Interactive Shell Mode
    run_clear();
    print_banner();

    std::string input;
    while (!g_shutdown_requested.load(std::memory_order_relaxed)) {
        std::cout << get_prompt();
        if (!std::getline(std::cin, input)) {
            std::cout << "\nLogging out of Jules OS...\n";
            break;
        }

        input = trim(input);

        if (input.empty()) continue;
        if (input == "exit") break;

        execute_command(input);
    }

    if (g_shutdown_requested.load(std::memory_order_relaxed)) {
        std::cout << COLOR_YELLOW << "\n[PID 1] Received shutdown signal. Shutting down gracefully...\n" << COLOR_RESET;
    }

    return 0;
}
