#ifndef COMMANDS_H
#define COMMANDS_H

#include <string>

namespace JulesOS {

std::string trim(const std::string& s);
void execute_command(const std::string& cmd);
void show_help();
void show_status();
void run_boost();
void run_python();
void run_jupdate();
void run_fetch();
void run_clear();
void run_system(const char* command);

} // namespace JulesOS

#endif
