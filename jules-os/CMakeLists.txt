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
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra -fno-exceptions -fno-rtti")

# Add the executable
add_executable(jules_shell
    src/shell.cpp
    src/commands.cpp
)

# Strip the binary to make it as small as possible
add_custom_command(TARGET jules_shell POST_BUILD
    COMMAND strip jules_shell
)
