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

// Test for write_sysfs (secure file writing)
TEST(CommandsTest, WriteSysfsWritesCorrectContent) {
    const std::string test_file = "test_sysfs_mock.txt";
    const std::string test_value = "performance";

    // Call function
    write_sysfs(test_file, test_value);

    // Verify content (including newline)
    std::ifstream ifs(test_file);
    std::string content((std::istreambuf_iterator<char>(ifs)),
                         std::istreambuf_iterator<char>());
    ifs.close();

    EXPECT_EQ(content, test_value + "\n");

    // Cleanup
    std::remove(test_file.c_str());
}

// Test for write_sysfs with potential injection characters
TEST(CommandsTest, WriteSysfsPreventsInjection) {
    const std::string test_file = "test_injection.txt";
    const std::string injection_value = "value; echo 'injected'";

    // Call function
    write_sysfs(test_file, injection_value);

    // Verify content - should contain exactly the injection_value string plus newline
    std::ifstream ifs(test_file);
    std::string content((std::istreambuf_iterator<char>(ifs)),
                         std::istreambuf_iterator<char>());
    ifs.close();

    EXPECT_EQ(content, injection_value + "\n");

    // Cleanup
    std::remove(test_file.c_str());
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
