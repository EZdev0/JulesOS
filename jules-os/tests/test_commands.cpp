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

// Test for show_help output
TEST(CommandsTest, ShowHelpOutput) {
    OutputCapture capture;

    show_help();

    std::string output = capture.getCout();
    EXPECT_NE(output.find("=== Jules OS Core Commands ==="), std::string::npos);
    EXPECT_NE(output.find("help"), std::string::npos);
    EXPECT_NE(output.find("status"), std::string::npos);
    EXPECT_NE(output.find("boost"), std::string::npos);
    EXPECT_NE(output.find("fetch"), std::string::npos);
    EXPECT_NE(output.find("python"), std::string::npos);
    EXPECT_NE(output.find("jupdate"), std::string::npos);
    EXPECT_NE(output.find("clear"), std::string::npos);
    EXPECT_NE(output.find("reboot"), std::string::npos);
    EXPECT_NE(output.find("poweroff"), std::string::npos);
}

// Test that "help" command triggers show_help
TEST(CommandsTest, HelpCommandTriggersShowHelp) {
    std::string help_output;
    {
        OutputCapture capture;
        show_help();
        help_output = capture.getCout();
    }

    OutputCapture capture;
    execute_command("help");
    EXPECT_EQ(capture.getCout(), help_output);
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
