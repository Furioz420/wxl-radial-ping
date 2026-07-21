# Embed the module's maintainable Lua sources into a generated header.  Keeping
# each raw string below MSVC's literal-size limit avoids checking generated code
# into the repository while still shipping one self-contained WarcraftXL DLL.
set(_wxl_radial_ping_lua
    "${CMAKE_CURRENT_LIST_DIR}/lua/Atlas.lua"
    "${CMAKE_CURRENT_LIST_DIR}/lua/Core.lua"
    "${CMAKE_CURRENT_LIST_DIR}/lua/World.lua"
    "${CMAKE_CURRENT_LIST_DIR}/lua/Wheel.lua"
    "${CMAKE_CURRENT_LIST_DIR}/lua/Init.lua"
    "${CMAKE_CURRENT_LIST_DIR}/lua/Settings.lua")

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_wxl_radial_ping_lua})
set(_wxl_radial_ping_generated "${CMAKE_CURRENT_BINARY_DIR}/generated/wxl-radial-ping")
set(_wxl_radial_ping_header "${_wxl_radial_ping_generated}/RadialPingLua.hpp")
file(MAKE_DIRECTORY "${_wxl_radial_ping_generated}")
file(WRITE "${_wxl_radial_ping_header}"
    "#pragma once\n#include <cstddef>\nnamespace wxl::scripts::radialping::generated {\n"
    "inline const char* const kLuaChunks[] = {\n")

foreach(_lua_file IN LISTS _wxl_radial_ping_lua)
    file(READ "${_lua_file}" _lua_source)
    string(LENGTH "${_lua_source}" _lua_length)
    set(_lua_offset 0)
    while(_lua_offset LESS _lua_length)
        math(EXPR _lua_remaining "${_lua_length} - ${_lua_offset}")
        if(_lua_remaining GREATER 12000)
            set(_lua_chunk_length 12000)
        else()
            set(_lua_chunk_length ${_lua_remaining})
        endif()
        string(SUBSTRING "${_lua_source}" ${_lua_offset} ${_lua_chunk_length} _lua_chunk)
        file(APPEND "${_wxl_radial_ping_header}" "R\"WXL_LUA(${_lua_chunk})WXL_LUA\",\n")
        math(EXPR _lua_offset "${_lua_offset} + ${_lua_chunk_length}")
    endwhile()
    file(APPEND "${_wxl_radial_ping_header}" "\"\\n\",\n")
endforeach()

file(APPEND "${_wxl_radial_ping_header}"
    "};\ninline constexpr std::size_t kLuaChunkCount = sizeof(kLuaChunks) / sizeof(kLuaChunks[0]);\n}\n")
target_include_directories(WarcraftXL PRIVATE "${_wxl_radial_ping_generated}")
