cmake_minimum_required(VERSION 3.10)
project(JulesOS VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Optimize for speed and size. Statically link to avoid dependency issues in the minimal rootfs.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra -static -fno-exceptions -fno-rtti")

add_executable(jules_shell
    src/shell.cpp
    src/commands.cpp
)

# Strip the binary to make it as small as possible
add_custom_command(TARGET jules_shell POST_BUILD
    COMMAND strip jules_shell
)
