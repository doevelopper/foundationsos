#include <cppbdd101/InterfaceTest.hpp>

using namespace cpp101::test;

log4cxx::LoggerPtr InterfaceTest::logger = log4cxx::Logger::getLogger(std::string("cppbdd101.InterfaceTest"));

InterfaceTest::InterfaceTest()
  : m_mockInterface(nullptr)
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
}

InterfaceTest::~InterfaceTest()
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
}

void InterfaceTest::SetUp ()
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
    m_mockInterface = new MockInterface();
}

void InterfaceTest::TearDown ()
{
    LOG4CXX_TRACE(logger , __LOG4CXX_FUNC__);
    // Verifies and removes the expectations on mock_obj; // returns true iff successful
    ::testing::Mock::VerifyAndClearExpectations(m_mockInterface);

    // Verifies and removes the expectations on mock_obj; also removes the default actions set by ON_CALL();
    ::testing::Mock::VerifyAndClear(m_mockInterface);
     delete m_mockInterface;
}
