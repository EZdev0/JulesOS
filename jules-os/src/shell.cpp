#include "commands.h"
#include <iostream>
#include <string>
#include <unistd.h>
#include <cstdlib>

using namespace JulesOS;

// ANSI Color Codes
const std::string BOLD = "\033[1m";
const std::string RESET = "\033[0m";
const std::string FG_CYAN = "\033[36m";
const std::string FG_MAGENTA = "\033[35m";
const std::string FG_GREEN = "\033[32m";
const std::string FG_YELLOW = "\033[33m";
const std::string FG_BLUE = "\033[34m";
const std::string BG_BLUE = "\033[44m";
const std::string FG_WHITE = "\033[37m";

void print_banner() {
    std::cout << FG_CYAN << BOLD << R"(
       __      __             ____  _____
      / /_  __/ /__  _____   / __ \/ ___/
 __  / / / / / / _ \/ ___/  / / / /\__ \
/ /_/ / /_/ / /  __(__  )  / /_/ /___/ /
\____/\__,_/_/\___/____/   \____//____/

)" << RESET;
    std::cout << FG_MAGENTA << BOLD << "    The Immutable, Intelligent, High-Performance Kernel Interface" << RESET << "\n";
    std::cout << FG_YELLOW << "    Type 'help' for built-in commands. Running on: " << FG_GREEN;
    system("uname -r");
    std::cout << RESET << "\n";
}

std::string get_prompt() {
    // Basic dynamic prompt showing current directory
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
        std::string dir(cwd);
        // Minimalize home directory path
        size_t pos = dir.find("/home");
        if (pos == 0) {
            dir.replace(0, 5, "~");
        }

        return BOLD + FG_BLUE + "╭─(" + FG_CYAN + "jules@os" + FG_BLUE + ")-[" + FG_GREEN + dir + FG_BLUE + "]\n╰─" + FG_MAGENTA + "❯ " + RESET;
    }
    return BOLD + FG_MAGENTA + "❯ " + RESET;
}

int main(int argc, char* argv[]) {
    // Handle command execution from scripts/init.sh if passed as argument
    if (argc > 1) {
        std::string cmd = "";
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
            // Handle EOF (Ctrl+D) gracefully
            std::cout << "\nLogging out of Jules OS...\n";
            break;
        }

        // Trim whitespace
        size_t first = input.find_first_not_of(' ');
        if (std::string::npos == first) continue;
        size_t last = input.find_last_not_of(' ');
        input = input.substr(first, (last - first + 1));

        if (input.empty()) continue;

        execute_command(input);
    }

    return 0;
}
