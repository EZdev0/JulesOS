#include <gtest/gtest.h>
#include "../src/commands.h"
#include <sstream>
#include <iostream>
#include <fstream>
#include <cstdio>

using namespace JulesOS;

// Helper to capture stdout/stderr
class OutputCapture {
public:
    OutputCapture() : old_cout(std::cout.rdbuf()), old_cerr(std::cerr.rdbuf()) {
        std::cout.rdbuf(capture_cout.rdbuf());
        std::cerr.rdbuf(capture_cerr.rdbuf());
    }
    ~OutputCapture() {
        std::cout.rdbuf(old_cout);
        std::cerr.rdbuf(old_cerr);
    }
    std::string getCout() const { return capture_cout.str(); }
    std::string getCerr() const { return capture_cerr.str(); }

private:
    std::stringstream capture_cout;
    std::stringstream capture_cerr;
    std::streambuf* old_cout;
    std::streambuf* old_cerr;
};

// Test for completely empty command string
TEST(CommandsTest, EmptyCommandProducesNoOutput) {
    OutputCapture capture;

    // Call function
    execute_command("");

    // Check results: output should be completely empty
    EXPECT_EQ(capture.getCout(), "");
    EXPECT_EQ(capture.getCerr(), "");
}

// Test for byte formatting utility
TEST(CommandsTest, FormatBytes) {
    EXPECT_EQ(format_bytes(0), "0.0B");
    EXPECT_EQ(format_bytes(1023), "1023.0B");
    EXPECT_EQ(format_bytes(1024), "1.0KiB");
    EXPECT_EQ(format_bytes(1536), "1.5KiB");
    EXPECT_EQ(format_bytes(1048576), "1.0MiB");
    EXPECT_EQ(format_bytes(1073741824), "1.0GiB");
    // 1 TiB = 1024^4 = 1099511627776
    EXPECT_EQ(format_bytes(1099511627776ULL), "1.0TiB");
}

// Test for run_clear function
TEST(CommandsTest, RunClearOutputsCorrectSequence) {
    OutputCapture capture;
    run_clear();
    EXPECT_EQ(capture.getCout(), "\033[2J\033[1;1H");
}

// Test for clear command
TEST(CommandsTest, ClearCommandCallsRunClear) {
    OutputCapture capture;
    execute_command("clear");
    EXPECT_EQ(capture.getCout(), "\033[2J\033[1;1H");
}

// Test for kernel release retrieval
TEST(CommandsTest, GetKernelRelease) {
    std::string release = get_kernel_release();
    EXPECT_FALSE(release.empty());
    // Since we don't know the exact version in the test environment,
    // we just ensure it's not the failure fallback if we expect success,
    // but even "unknown" is a valid return if uname fails.
    // In most CI/test environments, uname should succeed.
}

// Test for trim utility
TEST(CommandsTest, TrimUtility) {
    EXPECT_EQ(trim(""), "");
    EXPECT_EQ(trim("  "), "");
    EXPECT_EQ(trim(" \t\n\r "), "");
    EXPECT_EQ(trim("hello"), "hello");
    EXPECT_EQ(trim("  hello  "), "hello");
    EXPECT_EQ(trim("\t\nhello\r "), "hello");
    EXPECT_EQ(trim("  hello world  "), "hello world");
}

// Test for command containing only whitespace characters
TEST(CommandsTest, WhitespaceCommandProducesNoOutput) {
    OutputCapture capture;

    // Call function with different types of whitespace
    execute_command(" ");
    EXPECT_EQ(capture.getCout(), "");
    EXPECT_EQ(capture.getCerr(), "");

    execute_command("   \t  \n  ");
    EXPECT_EQ(capture.getCout(), "");
    EXPECT_EQ(capture.getCerr(), "");
}
