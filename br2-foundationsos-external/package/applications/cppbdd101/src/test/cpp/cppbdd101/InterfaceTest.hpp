#ifndef CPPBDD101_INTERFACETEST_HPP
#define CPPBDD101_INTERFACETEST_HPP

#include <gtest/gtest.h>
#include <log4cxx/logger.h>
#include <cppbdd101/MockInterface.hpp>

namespace cpp101::test
{
class InterfaceTest : public ::testing::Test
{
public:
   InterfaceTest();
   virtual ~InterfaceTest();

   virtual void SetUp ();
   virtual void TearDown ();

protected:

   MockInterface * m_mockInterface;
   static log4cxx::LoggerPtr logger;
};
}
#endif

