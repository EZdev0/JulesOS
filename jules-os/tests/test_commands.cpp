#include <gtest/gtest.h>
#include "../src/commands.h"
#include <sstream>
#include <iostream>

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
