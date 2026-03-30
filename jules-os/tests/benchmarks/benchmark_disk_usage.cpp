#include <iostream>
#include <chrono>
#include <vector>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/statvfs.h>
#include <string>
#include <cstring>
#include <cstdlib>

// Mocking execute_external from commands.cpp
void execute_external_mock(const std::string& cmd) {
    pid_t pid = fork();
    if (pid == -1) {
        return;
    } else if (pid == 0) {
        // Simple sh -c for the df command
        char* args[] = {(char*)"/bin/sh", (char*)"-c", (char*)cmd.c_str(), nullptr};
        execvp(args[0], args);
        exit(127);
    } else {
        int status;
        waitpid(pid, &status, 0);
    }
}

void use_statvfs_native(const std::string& path) {
    struct statvfs vfs;
    if (statvfs(path.c_str(), &vfs) == 0) {
        // Simulate calculations
        unsigned long long total = (unsigned long long)vfs.f_blocks * vfs.f_frsize;
        unsigned long long free = (unsigned long long)vfs.f_bfree * vfs.f_frsize;
        unsigned long long available = (unsigned long long)vfs.f_bavail * vfs.f_frsize;
        unsigned long long used = total - free;
        (void)used;
        (void)available;
    }
}

int main() {
    const int iterations = 50; // Fewer iterations since fork/exec is slow and we just want a baseline
    const std::string df_cmd = "df -h / /home 2>/dev/null || df -h /";

    std::cout << "Benchmarking 'df' fork/exec vs native 'statvfs()'..." << std::endl;

    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        execute_external_mock(df_cmd);
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_external = end - start;

    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        use_statvfs_native("/");
        use_statvfs_native("/home");
    }
    end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_native = end - start;

    std::cout << "\nResults for " << iterations << " iterations:" << std::endl;
    std::cout << "External 'df' (fork/exec) total time: " << diff_external.count() << "s" << std::endl;
    std::cout << "Average: " << diff_external.count() / iterations << "s per call." << std::endl;

    std::cout << "Native 'statvfs()' total time: " << diff_native.count() << "s" << std::endl;
    std::cout << "Average: " << diff_native.count() / iterations << "s per call." << std::endl;

    if (diff_native.count() > 0) {
        std::cout << "Measured Speedup: " << diff_external.count() / diff_native.count() << "x" << std::endl;
    }

    return 0;
}
