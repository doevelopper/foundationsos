
#include <cppbdd101/Dummy.hpp>

log4cxx::LoggerPtr cpp101::Dummy::logger = log4cxx::Logger::getLogger(std::string("cppbdd101.Dummy"));

cpp101::Dummy::Dummy()
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
}

cpp101::Dummy::~Dummy()
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
}

cpp101::Dummy::Dummy (const std::string& hello,  const std::string& world)
	: m_hello{hello}
	, m_world{world}
	, m_speechless{}
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
	m_speechless = (hello.empty() && world.empty());
}

std::string cpp101::Dummy::speak() const
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);

	auto hello = m_hello;
	hello.append(" ");
	hello.append(m_world);
	return (hello);
}

bool cpp101::Dummy::speechless() const
{
	LOG4CXX_TRACE(logger, __LOG4CXX_FUNC__);
	return m_speechless;
}


