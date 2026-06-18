#include <cmath>
#include <iostream>
#include <chrono>
#include <vector>
#include <string>

void run_without_reserve(const std::vector<std::string>& args, int iterations) {
    for (int i = 0; i < iterations; ++i) {
        std::vector<char*> c_args;
        for (const auto& arg : args) {
            c_args.push_back(const_cast<char*>(&arg[0]));
        }
        c_args.push_back(nullptr);
        // Prevent optimization from removing the loop
        if (c_args.empty()) std::cout << "Empty" << std::endl;
    }
}

void run_with_reserve(const std::vector<std::string>& args, int iterations) {
    for (int i = 0; i < iterations; ++i) {
        std::vector<char*> c_args;
        c_args.reserve(args.size() + 1);
        for (const auto& arg : args) {
            c_args.push_back(const_cast<char*>(&arg[0]));
        }
        c_args.push_back(nullptr);
        // Prevent optimization from removing the loop
        if (c_args.empty()) std::cout << "Empty" << std::endl;
    }
}

int main() {
    const int iterations = 1000000;
    std::vector<std::string> args = {"ls", "-l", "-a", "--color=always", "/home/jules/test_directory"};

    std::cout << "Benchmarking vector population with " << args.size() << " elements (" << iterations << " iterations)" << std::endl;

    auto start = std::chrono::high_resolution_clock::now();
    run_without_reserve(args, iterations);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_without = end - start;

    start = std::chrono::high_resolution_clock::now();
    run_with_reserve(args, iterations);
    end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff_with = end - start;

    std::cout << "Without reserve: " << diff_without.count() << "s" << std::endl;
    std::cout << "With reserve:    " << diff_with.count() << "s" << std::endl;

    if (diff_with.count() > 0) {
        std::cout << "Speedup: " << diff_without.count() / diff_with.count() << "x" << std::endl;
        std::cout << "Improvement: " << (1.0 - diff_with.count() / diff_without.count()) * 100.0 << "%" << std::endl;
    }

    return 0;
}
