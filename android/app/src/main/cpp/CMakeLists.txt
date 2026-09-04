cmake_minimum_required(VERSION 3.22.1)
project("termux_pty")

add_library(termux_pty SHARED termux_pty.cpp)
target_link_libraries(termux_pty log)
