
#ifndef CPPBDD101_MOCKINTERFACE_HPP
#define CPPBDD101_MOCKINTERFACE_HPP

#include <gmock/gmock.h>
#include <log4cxx/logger.h>
#include <cppbdd101/Interface.hpp>

namespace cpp101::test
{
class MockInterface : public ::testing::NiceMock<Interface>
{

public:
   MockInterface();
   ~MockInterface();

   MOCK_METHOD0(play, void());
   MOCK_METHOD0(stop, void());
   MOCK_METHOD0(pause, void());
   MOCK_CONST_METHOD0(state, int());

private:

  static log4cxx::LoggerPtr logger;

};
}
#endif

