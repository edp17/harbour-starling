cmake_minimum_required(VERSION 3.6)
project(harbour-starling)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 COMPONENTS Core Gui Qml Quick Network REQUIRED)

# SailfishApp (IMPORTANT)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)
pkg_check_modules(SAILFISHSECRETS REQUIRED sailfishsecrets)

add_executable(harbour-starling
    src/main.cpp
    src/starlingclient.cpp
    src/starlingclient.h
    src/tokenstore.cpp
    src/tokenstore.h
)

target_include_directories(harbour-starling PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${SAILFISHAPP_INCLUDE_DIRS}
    ${SAILFISHSECRETS_INCLUDE_DIRS}
)

target_link_libraries(harbour-starling
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::Network
    crypto
    ${SAILFISHAPP_LIBRARIES}
    ${SAILFISHSECRETS_LIBRARIES}
)

target_compile_options(harbour-starling PRIVATE
    ${SAILFISHSECRETS_CFLAGS_OTHER}
)

install(TARGETS harbour-starling
    RUNTIME DESTINATION bin
)

install(FILES harbour-starling.desktop
    DESTINATION share/applications
)

install(FILES icons/harbour-starling.png
    DESTINATION share/icons/hicolor/172x172/apps
)

install(DIRECTORY qml
    DESTINATION share/harbour-starling
)
