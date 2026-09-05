cmake_minimum_required(VERSION 3.19)

project(WhereIsMyMoney
    VERSION 0.1.0
    DESCRIPTION "个人记账程序 - Qt Quick + SQLite, Fluent Design"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# 让 Release 构建默认启用优化
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.4 REQUIRED COMPONENTS Quick)

qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(WhereIsMyMoney
    src/main.cpp
)

qt_add_qml_module(WhereIsMyMoney
    URI WhereIsMyMoney
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
)

set_target_properties(WhereIsMyMoney PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

target_link_libraries(WhereIsMyMoney PRIVATE
    Qt6::Quick
)
