#include <iostream>
#include <chrono>
#include <vector>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/utsname.h>

// Mocking execute_external from commands.cpp
void execute_external_mock(const std::string& cmd) {
    if (cmd == "uname -r") {
        pid_t pid = fork();
        if (pid == 0) {
            char* args[] = {(char*)"uname", (char*)"-r", nullptr};
            execvp(args[0], args);
            exit(1);
        } else {
            waitpid(pid, nullptr, 0);
        }
    }
}

void use_uname_syscall() {
    struct utsname buffer;
    if (uname(&buffer) == 0) {
        // std::cout << buffer.release << std::endl;
    }
}

int main() {
    const int iterations = 1000;

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        execute_external_mock("uname -r");
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_external = end - start;

    // To keep it fair, we should probably suppress output during benchmark or just not print it.
    // Actually, execute_external_mock DOES print it because it calls uname.

    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        use_uname_syscall();
    }
    end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_syscall = end - start;

    std::cout << "Iterations: " << iterations << std::endl;
    std::cout << "External 'uname -r' (fork/exec) total time: " << diff_external.count() << "s" << std::endl;
    std::cout << "Average time: " << diff_external.count() / iterations << "s" << std::endl;

    std::cout << "Syscall 'uname()' total time: " << diff_syscall.count() << "s" << std::endl;
    std::cout << "Average time: " << diff_syscall.count() / iterations << "s" << std::endl;

    std::cout << "Speedup: " << diff_external.count() / diff_syscall.count() << "x" << std::endl;

    return 0;
}
