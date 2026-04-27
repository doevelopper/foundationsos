#include <cppbdd101/Application.hpp>
#include <locale>
#include <cstdlib>      /* getenv */
#include <cstdio>

using namespace cpp101;

log4cxx::LoggerPtr Application::logger = log4cxx::Logger::getLogger(std::string("cppbdd101.Application"));

Application::Application()
	: m_loggerService(new Logger(5000))
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
	LOG4CXX_INFO(logger, std::locale("").name().c_str());
}

Application::Application(int argc, char *argv[])
	: m_loggerService(new Logger(5000))
//  , m_argc(argc)
//  , m_argv(argv)
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
}

Application::~Application()
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
	delete this->m_loggerService;
}
