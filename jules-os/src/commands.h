#ifndef COMMANDS_H
#define COMMANDS_H

#include <string>

namespace JulesOS {

// Command handlers
void execute_command(const std::string& cmd);
void show_help();
void show_status();
void run_boost();
void run_python();
void run_update();
void run_clear();

} // namespace JulesOS

#endif // COMMANDS_H
