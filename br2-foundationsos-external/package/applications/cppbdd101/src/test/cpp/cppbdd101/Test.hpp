
#ifndef CPPBDD101_TEST_HPP
#define CPPBDD101_TEST_HPP

#include <vector>
#include <gmock/gmock.h>
#include <cppbdd101/Logger.hpp>

namespace cpp101::test
{
    class Test
    {
        public:

            Test();
            Test(std::string & suite, unsigned int iteration = 1);
            Test(const Test & orig) = default;
            virtual ~Test();

            int run (int argc = 0, char * argv[] = NULL);
            static void showUsage(std::string name);

        private:

            std::string m_testSuites;
            unsigned int m_numberOfTestIteration;
            static const  unsigned long LOGGER_WATCH_DELAY;
            cpp101::Logger * m_loggerService;
            /*!
             * @brief Class logger.
             */
            static log4cxx::LoggerPtr logger;
        };
}

#endif
