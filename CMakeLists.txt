cmake_minimum_required(VERSION 3.20)
project(NativeMessageBox LANGUAGES C CXX)

include(CTest)
enable_testing()

add_subdirectory(src/native)
