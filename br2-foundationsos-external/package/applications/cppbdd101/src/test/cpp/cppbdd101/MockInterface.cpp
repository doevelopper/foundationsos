#include <cppbdd101/MockInterface.hpp>

using namespace cpp101::test;

log4cxx::LoggerPtr MockInterface::logger = log4cxx::Logger::getLogger(std::string("cppbdd101.MockInterface"));

MockInterface::MockInterface()
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
}
MockInterface::~MockInterface()
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
}
