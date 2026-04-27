#       CMakeLists.txt
#
#               Copyright (c) 2014-2018 A.H.L
#
#        Permission is hereby granted, free of charge, to any person obtaining
#        a copy of this software and associated documentation files (the
#        "Software"), to deal in the Software without restriction, including
#        without limitation the rights to use, copy, modify, merge, publish,
#        distribute, sublicense, and/or sell copies of the Software, and to
#        permit persons to whom the Software is furnished to do so, subject to
#        the following conditions:
#
#        The above copyright notice and this permission notice shall be
#        included in all copies or substantial portions of the Software.
#
#        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#        NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#        LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#        OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#        WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

add_library(${PROJECT_NAME}.main)

target_sources(${PROJECT_NAME}.main
    PRIVATE
        cppbdd101/Dummy
        cppbdd101/Interface
        cppbdd101/internal/LoggerPrivate
        cppbdd101/Logger
        cppbdd101/Application
)

apply_style_targets(${PROJECT_NAME}.main ${CMAKE_CURRENT_SOURCE_DIR})
add_cppcheck_analysis(${PROJECT_NAME}.main ${CMAKE_CURRENT_SOURCE_DIR})
add_code_linter(${PROJECT_NAME}.main ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
add_cyclomatic_complexity_analyzer(${PROJECT_NAME}.main ${CMAKE_CURRENT_SOURCE_DIR})

option(EXCLUDE_DEPRECATED "Exclude deprecated parts of the library" TRUE)
if (EXCLUDE_DEPRECATED)
    set(NO_BUILD_DEPRECATED DEFINE_NO_DEPRECATED)
endif()

include(GenerateExportHeader)
generate_export_header(${PROJECT_NAME}.main
    EXPORT_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/cppbdd101/Cpp101_Export.hpp"
    INCLUDE_GUARD_NAME CPP101_EXPORT_HPP
    EXPORT_MACRO_NAME API_DECLS
    BASE_NAME cpp101
    PREFIX_NAME CPP101_
    #STATIC_DEFINE BUILT_AS_STATIC
    DEPRECATED_MACRO_NAME CPP101_DEPRECATED
    ${NO_BUILD_DEPRECATED}
)

if(NOT TARGET MAIN::MAIN)
    add_library(MAIN::MAIN UNKNOWN IMPORTED)
    set_target_properties(MAIN::MAIN PROPERTIES
        INTERFACE_COMPILE_DEFINITIONS "${MAIN_DEFINITIONS}"
        IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
        IMPORTED_LOCATION "${CMAKE_INSTALL_LIBDIR}/${PROJECT_NAME}.main.a"
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101"
    )
endif(NOT TARGET MAIN::MAIN)

#set_property(TARGET ${PROJECT_NAME}.main PROPERTY CXX_STANDARD 17)
#set_property(TARGET ${PROJECT_NAME}.main PROPERTY VERSION ${PROJECT_VERSION})
#set_property(TARGET ${PROJECT_NAME}.main PROPERTY SOVERSION ${PROJECT_VERSION})

target_compile_features(${PROJECT_NAME}.main
    PUBLIC
        cxx_std_17
        cxx_strong_enums
        cxx_variadic_templates
        cxx_nullptr
        cxx_alias_templates
        cxx_auto_type
        cxx_constexpr
        cxx_defaulted_functions
        cxx_final
        cxx_lambdas
        cxx_noexcept
        cxx_nullptr
        cxx_rvalue_references
        cxx_thread_local
        cxx_variadic_templates
        cxx_override
    PRIVATE
        cxx_lambdas
        cxx_range_for
        $<$<CXX_COMPILER_ID:GNU>:cxx_attributes>
)

target_compile_definitions(${PROJECT_NAME}.main
    PRIVATE
        "VERBOSITY=$<IF:$<BOOL:${VERBOSE}>,30,10>"
        $<$<OR:$<CONFIG:Release>,$<CONFIG:Debug>>: -DRELEASE_LEVEL="SNAPSHOOT"> # SNAPSHOOT ,ALPHA , BETA , CANDIDATE , FINAL.
        $<$<CXX_COMPILER_ID:GNU>: NOMINMAX>
        # -D_GLIBCXX_SANITIZE_VECTOR
        #QNX POSIX XENOMAI PREEMPT_RT
)

target_compile_options(${PROJECT_NAME}.main
    INTERFACE
        $<$<CONFIG:Debug>:-g3 -O0 -fstack-protector>
        $<$<CONFIG:Release>:-g0 -O2>
    PUBLIC
        $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>>: -W -Wextra -Weffc++ -Wall -pedantic-errors -Wconversion -Wsign-conversion>

        $<IF:$<COMPILE_LANGUAGE:CXX>,-Wold-style-cast,>

        $<$<CONFIG:Release>:${MY_RELEASE_OPTIONS}>
        $<$<CONFIG:Release>:-ffunction-sections>
        $<$<CONFIG:Release>:-fdata-sections>
        $<$<CONFIG:Release>:-Wl,--gc-sections>

        $<$<CONFIG:Debug>:${MY_DEBUG_OPTIONS}>
        $<$<CONFIG:Debug>:-O0>
        $<$<CONFIG:Debug>:-ggdb>
        $<$<CONFIG:Debug>: -O0 -g -D_DEBUG -D_FORTIFY_SOURCE=2 -fno-strict-aliasing -fno-omit-frame-pointer>

        $<$<CONFIG:Release>:API_DECLS>
        $<$<CONFIG:Release>:LOG4CXX_STATIC>
        $<$<CONFIG:Release>:APR_DECLARE_STATIC>
        $<$<OR:$<CONFIG:Release>,$<CONFIG:PROF>>:DISABLE_VAR>

        $<$<COMPILE_LANGUAGE:CXX>:-DNDEBUG -O3 -pipe -Wpedantic>
        $<$<COMPILE_LANGUAGE:CXX>:-fmax-errors=5 -Werror=shadow -fdiagnostics-parseable-fixits>
        $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor -Woverloaded-virtual -Wuseless-cast -Wlogical-op -Wduplicated-branches>


        $<$<CONFIG:Coverage>:-O0  -fprofile-arcs -ftest-coverage --coverage>

        $<$<CONFIG:Profile>:-fsanitize=memory -fsanitize-memory-track-origins=2 -fno-omit-frame-pointer -fsanitize=null>
        $<$<CONFIG:Profile>:-fsanitize=unreachable -fstack-check -fvtable-verify=std>
#        $<IF:$<CONFIG:Debug>: helper_debug.cpp,helper_release.cpp>
        $<$<OR:$<CONFIG:Release>,$<CONFIG:Profile>>: DISABLE_VAR>
        $<$<CONFIG:Coverage>: -O0  ${CPP_COVERAGE_FLAGS}>
        $<$<CONFIG:Profile>: ${CHECK_MEMORY_FLAGS}>

)

target_include_directories(${PROJECT_NAME}.main
    PUBLIC
         $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101>
         $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
         $<INSTALL_INTERFACE:include/cppbdd101>

#        $<BUILD_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/cppbdd101>
#        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101>
#        $<INSTALL_INTERFACE:${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/cppbdd101>
#        $<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}>
#        $<INSTALL_INTERFACE:${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/cppbdd101>
#    INTERFACE
#        $<BUILD_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/cppbdd101>
#        $<INSTALL_INTERFACE:include>

     SYSTEM
         PUBLIC
             ${CMAKE_INSTALL_INCLUDEDIR}/cppbdd101
)

target_link_libraries(${PROJECT_NAME}.main
    PUBLIC
        $<$<PLATFORM_ID:Linux>:rt>
        $<$<PLATFORM_ID:Linux>:pthread>
        $<$<CONFIG:Coverage>:${CPP_COVERAGE_FLAGS}>
#        $<$<OR:$<CXX_COMPILER_ID:Clang>, $<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>>:${BLD_FLAGS}>
        LOG4CXX::LOG4CXX
)
#target_link_options(${PROJECT_NAME}.main
#    PUBLIC
#        -m64
#)

set_target_properties( ${PROJECT_NAME}.main PROPERTIES
    #    LINK_FLAGS
    #        -m64
    VERSION
        ${PROJECT_VERSION}
    SOVERSION
        "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
)



#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#
#                                 EXECUTABLES
#
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------



add_executable(${PROJECT_NAME}.main.bin
    cppbdd101/main
)

target_link_libraries(${PROJECT_NAME}.main.bin
    PUBLIC
        ${PROJECT_NAME}.main
)


#target_sources(edac
#    PRIVATE EdacError EdacError
#    PUBLIC Header.hpp)

#set_target_properties(cppbdd101.main
#    PROPERTIES
#    VERSION ${${PROJECT_NAME}_VERSION}
#)

#set_target_properties( cppbdd101.main  PROPERTIES
#    DEFINE_SYMBOL MAKEDLL
#    PUBLIC_HEADER "${CMAKE_CURRENT_SOURCE_DIR}"
#)

#INSTALL(TARGETS qjson EXPORT qjson-export
#        LIBRARY DESTINATION ${LIB_INSTALL_DIR}
#        RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
#        ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
#        FRAMEWORK DESTINATION ${FRAMEWORK_INSTALL_DIR}
#        PUBLIC_HEADER DESTINATION ${INCLUDE_INSTALL_DIR}/qjson
#)

#install(TARGETS target
#        CONFIGURATIONS Debug
#        RUNTIME DESTINATION Debug/bin)
#install(TARGETS target
#        CONFIGURATIONS Release
#        RUNTIME DESTINATION Release/bin)

