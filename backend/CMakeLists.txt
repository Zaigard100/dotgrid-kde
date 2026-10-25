cmake_minimum_required(VERSION 3.21)
project(dotgridlive LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick DBus)
qt_standard_project_setup(REQUIRES 6.5)

# One shared library that is both the backing target and the QML plugin.
# The module ends up in <build>/qml/org/dotgrid/live/backend/.
qt_add_qml_module(dotgridlivebackend
    URI org.dotgrid.live.backend
    VERSION 1.0
    PLUGIN_TARGET dotgridlivebackend
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/dotgrid/live/backend
    SOURCES
        starfield.h starfield.cpp
        battery.h battery.cpp
        livestate.h livestate.cpp
)

target_link_libraries(dotgridlivebackend PRIVATE Qt6::Quick Qt6::DBus)
target_compile_options(dotgridlivebackend PRIVATE -Wall -Wextra)
