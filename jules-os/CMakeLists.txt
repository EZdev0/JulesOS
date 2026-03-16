cmake_minimum_required(VERSION 3.10)
project(JulesOS VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Option to enable/disable static linking
option(STATIC_BUILD "Build a statically linked binary" ON)

if(STATIC_BUILD)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static")
    message(STATUS "Building statically linked binary")
else()
    message(STATUS "Building dynamically linked binary")
endif()

# Common flags for performance and size
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra")

# Add the executable
add_executable(jules_shell
    src/shell.cpp
    src/commands.cpp
)

# Strip the binary to make it as small as possible
add_custom_command(TARGET jules_shell POST_BUILD
    COMMAND strip jules_shell
)

# Option to enable/disable tests
option(BUILD_TESTING "Build the unit tests" OFF)

if(BUILD_TESTING)
    # Testing requires exceptions for gtest to work well natively, but since we disable them
    # globally, we must remove it for tests or find a workaround. For simplicity, we override it.
    # We create a new target for testing

    # We need exceptions and rtti for gtest
    set(TEST_CXX_FLAGS "-O3" "-Wall" "-Wextra")

    include(FetchContent)
    FetchContent_Declare(
      googletest
      GIT_REPOSITORY https://github.com/google/googletest.git
      GIT_TAG        release-1.12.1
    )
    # For Windows: Prevent overriding the parent project's compiler/linker settings
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    enable_testing()

    add_executable(jules_tests
        tests/test_commands.cpp
        src/commands.cpp
    )

    target_compile_options(jules_tests PRIVATE ${TEST_CXX_FLAGS})
    # Remove -fno-exceptions -fno-rtti for tests from CMAKE_CXX_FLAGS locally to the target if needed
    # (Since CMAKE_CXX_FLAGS applies to all, we might need a workaround or just rely on the above)

    target_link_libraries(jules_tests gtest_main)

    include(GoogleTest)
    gtest_discover_tests(jules_tests)
endif()
