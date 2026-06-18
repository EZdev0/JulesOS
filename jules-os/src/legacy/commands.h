#ifndef COMMANDS_H
#define COMMANDS_H

#include <string>

namespace JulesOS {

// ── Centralized ANSI Color Constants ──────────────────────────
// Defined once in commands.cpp, used everywhere via extern.
extern const std::string COLOR_RESET;
extern const std::string COLOR_RED;
extern const std::string COLOR_GREEN;
extern const std::string COLOR_YELLOW;
extern const std::string COLOR_BLUE;
extern const std::string COLOR_MAGENTA;
extern const std::string COLOR_CYAN;
extern const std::string BOLD;

// ── Utility Functions ─────────────────────────────────────────
std::string trim(const std::string& s);
std::string format_bytes(unsigned long long bytes);

// ── Core Commands ─────────────────────────────────────────────
void execute_command(const std::string& cmd);
void execute_external(const std::string& cmd);
void show_help();
void show_status();
void run_boost();
void run_python();
void run_jupdate();
void run_fetch();
void run_clear();
std::string get_kernel_release();
void write_sysfs(const std::string& path, const std::string& value);
void print_disk_usage(const std::string& path);

} // namespace JulesOS

#endif
