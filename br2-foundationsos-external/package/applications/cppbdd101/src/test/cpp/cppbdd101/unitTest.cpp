#include <iostream>
#include <cstdlib>

//#include <cppbdd101/edac/Test.hpp>
#include <cppbdd101/Test.hpp>

int main(int argc, char**argv) 
{
    //cppbdd101::edac::Test cppbdd101Test;
    cpp101::test::Test cppbdd101Test;

#if !defined(HAVE_LOG4CXX)
    std::cout << "TEST CPP-101: C++ Object Oriented Programming!" << std::endl;
    std::cout << "Simple and obvious Unit test frameworks" << std::endl;
    std::cout << "Each Test module should be able to have many small test cases." << std::endl;
#else
    LOG4CXX_TRACE(log4cxx::Logger::getRootLogger(),"TEST CPP-101: C++ Object Oriented Programming!");
    LOG4CXX_TRACE(log4cxx::Logger::getRootLogger(),"Simple and obvious Unit test frameworks");
    LOG4CXX_TRACE(log4cxx::Logger::getRootLogger(),"Each Test module should be able to have many small test cases.");
#endif
    LOG4CXX_INFO(log4cxx::Logger::getRootLogger() , __LOG4CXX_FUNC__ );

    cppbdd101Test.run(argc,argv);

    return (EXIT_SUCCESS);
}
