

set(FEATURE_TEST_FORMAT --format progress)  #--format pretty OR --format pretty --tags @wip OR ...
set(FEATURE_TEST_OPTION --backtrace --format html --color)

add_executable(cppbdd101.it-test.steps
    cppbdd101/features/step_definitions/DummyTestSteps
    cppbdd101/features/step_definitions/ApplicationSteps
    cppbdd101/features/step_definitions/MockInterfaceContext
)

target_link_libraries(cppbdd101.it-test.steps
    PUBLIC  
        cppbdd101.main
        cppbdd101.test
        CUCUMBER-CPP::CUCUMBER-CPP
#        PUBLIC BENCHMARK::BENCHMARK
)

add_custom_target(cppbdd101.integration-test

    COMMAND
        ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/qa/test-result

    COMMAND
        cppbdd101.it-test.steps --port 3902  >/dev/null &

    COMMAND 
        cucumber ${FEATURE_TEST_FORMAT} ${FEATURE_TEST_OPTION} 
#            --out ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/cppbdd101-cucumber-report.html 
            --out ${CMAKE_INSTALL_PREFIX}/qa/test-result/cppbdd101-test-report.html
            --strict ${CMAKE_CURRENT_SOURCE_DIR}/cppbdd101/features

    WORKING_DIRECTORY 
        ${CMAKE_CURRENT_SOURCE_DIR}

    COMMENT 
        "Start cucumber's wire server on port 3902 and run cppbdd101 integration test."
)

#add_custom_command(TARGET cppbdd101.integration-test
#    PRE_BUILD
#    COMMAND
#        cppbdd101.it-test.steps --port 3902  >/dev/null &
#    WORKING_DIRECTORY
#        ${CMAKE_CURRENT_SOURCE_DIR}
#    COMMENT
#        "Start cucumber's wire server on port 3902."
#)

add_custom_command(TARGET cppbdd101.integration-test 
    POST_BUILD
    COMMAND
        fuser -k -n  tcp 3902 || true # kill -9 *.it-test.steps which is using port 3902
        # iptables -I INPUT -p tcp --dport 3902 -j DROP ;# need to be root for this command
    COMMENT
        // check pro opened lsof -i -P -n | grep LISTEN 
        "Killing process to close cucumber wire port. (bind: Address already in use)"
)

#add_dependencies( feature-test cppbdd101.main.bin)
add_dependencies( feature-test cppbdd101.integration-test)
# Target: run wip features
# Run cucumber with --wip argument and run only features tagged @wip

#add_custom_target(run_wip_features
#    ${CUCUMBER_RUBY} -P --tags @wip --wip --tags ~@proposal --no-color -f pretty -s features
#    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#    COMMENT "Running cucumber (wip features)."
#)

# Target: document features
# Run all features except features tagged @wip or @proposal and generate html output

#add_custom_target(document_features
#    ${CUCUMBER_RUBY} -P --tags ~@wip --tags ~@proposal --no-color -f pretty --no-source -f html -o ${DOC_DIR}/Features.html features
#    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#    COMMENT "Running cucumber (features documentation)."
#)

