#include "commands.h"
#include <iostream>
#include <string>
#include <unistd.h>
#include <cstdlib>
#include <vector>
#include <cstring>

using namespace JulesOS;

// ANSI Color Codes
const std::string BOLD = "\033[1m";
const std::string RESET = "\033[0m";
const std::string FG_CYAN = "\033[36m";
const std::string FG_MAGENTA = "\033[35m";
const std::string FG_GREEN = "\033[32m";
const std::string FG_YELLOW = "\033[33m";
const std::string FG_BLUE = "\033[34m";

void print_banner() {
    std::cout << FG_CYAN << BOLD << R"(
       __      __             ____  _____
      / /_  __/ /__  _____   / __ \/ ___/
 __  / / / / / / _ \/ ___/  / / / /\__ \
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /
\____/\__,_/_/\___/____/   \____//____/

)" << RESET;
    std::cout << FG_MAGENTA << BOLD << "    The Immutable, Intelligent, High-Performance Kernel Interface" << RESET << "\n";
    std::cout << FG_YELLOW << "    Type 'help' for built-in commands. Running on: " << FG_GREEN << get_kernel_release() << RESET << "\n";
}

std::string get_prompt() {
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
        std::string dir(cwd);
        size_t pos = dir.find("/home");
        if (pos == 0) {
            dir.replace(0, 5, "~");
        }
        return BOLD + FG_BLUE + "╭─(" + FG_CYAN + "jules@os" + FG_BLUE + ")-[" + FG_GREEN + dir + FG_BLUE + "]\n╰─" + FG_MAGENTA + "❯ " + RESET;
    }
    return BOLD + FG_MAGENTA + "❯ " + RESET;
}

int main(int argc, const char* argv[]) {
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
        total_length += (argc - 2); // Spaces between arguments

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
    while (true) {
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

    return 0;
}
