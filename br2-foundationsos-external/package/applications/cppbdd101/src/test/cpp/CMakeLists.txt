
add_library(cppbdd101.test
	cppbdd101/Test
)

target_include_directories(cppbdd101.test 
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101>
        $<INSTALL_INTERFACE:${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/cppbdd101>
)

target_link_libraries(cppbdd101.test
    PUBLIC  
        cppbdd101.main
        GMock::GMock
        GTest::GTest
)

add_executable (cppbdd101.test.bin
    cppbdd101/unitTest
    cppbdd101/DummyTest
    cppbdd101/MockInterface
    cppbdd101/InterfaceTest
)

target_link_libraries(cppbdd101.test.bin
    PUBLIC cppbdd101.test
)

gtest_discover_tests(cppbdd101.test.bin
    TEST_PREFIX "CPPBDD101:-: "
    TEST_SUFFIX ----
    PROPERTIES LABELS CPPBDD101 TEST
    DISCOVERY_TIMEOUT 10
    EXTRA_ARGS --iterration 1 --outputpath ${CMAKE_RUNTIME_OUTPUT_DIRECTORY} --module cppbdd101.test.test
    WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
)

#add_dependencies( test cppbdd101.test.bin)

# add_custom_command(TARGET cppbdd101.test.bin
                   # POST_BUILD
                   # COMMAND ctest -C $<CONFIGURATION> --output-on-failure
# )

				   
#set_target_properties(
#    cppbdd101.test
#    PROPERTIES IMPORTED_LOCATION
#    "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/cppbdd101.test"
#)

#set_target_properties(
#    cppbdd101.test PROPERTIES
#    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101"
#)


#target_include_directories(cppbdd101.test PUBLIC
#    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>
#    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101>
#    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/cppbdd101>
#)

#target_compile_definitions(cppbdd101.test PUBLIC
#    ${TEST_BUILD_OPTIONS}
#    $<$<OR:$<CONFIG:Release>,$<CONFIG:Profiling>>:DISABLE_CONF>
#)

