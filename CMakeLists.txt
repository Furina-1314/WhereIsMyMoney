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

find_package(Qt6 6.4 REQUIRED COMPONENTS Quick Sql)

qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

# 数据层静态库：数据库管理器（账目/类别/付款账户/预算）
qt_add_library(core STATIC
    src/database/DatabaseManager.h
    src/database/DatabaseManager.cpp
)
target_include_directories(core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(core PUBLIC Qt6::Sql)

qt_add_executable(WhereIsMyMoney
    src/main.cpp
)

set_source_files_properties(src/qml/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(WhereIsMyMoney
    URI WhereIsMyMoney
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/Theme.qml
        src/qml/components/FluentButton.qml
        src/qml/components/FluentTextField.qml
        src/qml/components/FluentComboBox.qml
        src/qml/components/FluentDialog.qml
        src/qml/components/FluentScrollBar.qml
        src/qml/components/FluentSegmented.qml
        src/qml/components/TransactionDialog.qml
        src/qml/components/ManageEntitiesDialog.qml
        src/qml/components/EntityManagePanel.qml
        src/qml/pages/HomePage.qml
        src/qml/pages/StatsPage.qml
        src/qml/pages/BudgetPage.qml
        src/qml/pages/SettingsPage.qml
)

set_target_properties(WhereIsMyMoney PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
)

target_link_libraries(WhereIsMyMoney PRIVATE
    Qt6::Quick
    core
)

# 数据层自测（ctest 或直接运行 build/dbtest.exe）
enable_testing()
add_executable(dbtest tests/dbtest/main.cpp)
target_link_libraries(dbtest PRIVATE core)
add_test(NAME dbtest COMMAND dbtest)
