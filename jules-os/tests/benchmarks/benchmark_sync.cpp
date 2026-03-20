#include <iostream>
#include <chrono>
#include <unistd.h>
#include <sys/wait.h>
#include <vector>
#include <string>
#include <cstring>
#include <cstdlib>

// Mocking a simplified execute_external to measure overhead
void mock_execute_external(const std::string& cmd) {
    std::vector<char*> args;
    char* cmd_copy = strdup(cmd.c_str());
    args.push_back(cmd_copy);
    args.push_back(nullptr);

    pid_t pid = fork();
    if (pid == 0) {
        execvp(args[0], args.data());
        exit(0);
    } else if (pid > 0) {
        waitpid(pid, nullptr, 0);
    }
    free(cmd_copy);
}

int main() {
    const int iterations = 100;

    std::cout << "Benchmarking execute_external(\"sync\") vs sync()..." << std::endl;

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        mock_execute_external("sync");
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_external = end - start;
    std::cout << "execute_external(\"sync\") took: " << diff_external.count() << "s for " << iterations << " iterations." << std::endl;
    std::cout << "Average: " << diff_external.count() / iterations << "s per call." << std::endl;

    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        sync();
    }
    end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_native = end - start;
    std::cout << "native sync() took: " << diff_native.count() << "s for " << iterations << " iterations." << std::endl;
    std::cout << "Average: " << diff_native.count() / iterations << "s per call." << std::endl;

    if (diff_native.count() < diff_external.count()) {
        std::cout << "Speedup: " << diff_external.count() / diff_native.count() << "x" << std::endl;
    } else {
        std::cout << "No speedup measured (likely I/O bound or jitter)." << std::endl;
    }

    return 0;
}
