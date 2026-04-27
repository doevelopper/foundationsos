#ifndef CPPBDD101_APPLICATION_HPP
#define CPPBDD101_APPLICATION_HPP

#include <cppbdd101/Logger.hpp>

namespace cpp101
{
class Application {
public:
Application();
Application(int argc, char *argv[]);
Application(const Application&) = delete;
Application(Application&&) = delete;
Application& operator=(const Application&) = delete;
Application& operator=(Application&&) = delete;
virtual ~Application();
private:
Logger * m_loggerService;
static const long m_fileMonitorDelay = 5000UL;
static log4cxx::LoggerPtr logger;
//int m_argc;
//char * m_argv[];
};
}
#endif

