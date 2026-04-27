
#include <unistd.h>
#include <iostream>
#include <typeinfo>

#include <cppbdd101/internal/LoggerPrivate.hpp>

using cpp101::internal::LoggerPrivate;

std::string LoggerPrivate::m_loggerConfigLocation = "LOG4CXX_CONFIGURATION_PATH =/etc/cfg/log4cxx.xml";

LoggerPrivate::LoggerPrivate( unsigned long delay )
	: m_watchPeriod( delay )
{
	std::string configurationPath( "" );

	if( log4cxx::LogManager::getLoggerRepository( )->isConfigured( ) )
	{
		throw std::logic_error( "log4cxx configuration detected" );
	}
	else
	{
		try
		{
			if( const char * filePath = std::getenv( "LOG4CXX_CONFIGURATION" ) )
			{
				std::cerr << "Failed to get loggger configuratin file" << std::endl;
			}
			else
			{
				configurationPath.assign( filePath );
			}
		}
		catch ( std::exception & e )
		{
			std::cout << typeid (e).name( ) << ": " << e.what( ) << std::endl;
		}
		catch ( log4cxx::helpers::Exception & e )
		{
			std::cout << typeid (e).name( ) << ": " << e.what( ) << std::endl;
		}
		catch ( ... )
		{
			std::cerr << " ??? " << std::endl;
		}
	}

	if( configurationPath.empty( ) /*&& getenv(log4cxx.properties)*/ )
	{
		// log4cxx::PatternLayoutPtr layout   (new log4cxx::PatternLayout  (
		// "%d{yyyy-MM-dd HH:mm:ss.SSS} (%-6c) [%-6p] [%-5t] [%r] (%-10.20l:%L) -- %m%n"));
		// "[%-6.6p] %d{HH:mm:ss.SSS} [%15.15t] [%7.7r] (%20.20c)  (%-10.20l) - %-20.20M - %m%n"
		log4cxx::PatternLayoutPtr layout( new log4cxx::PatternLayout(
							  "[%-6.6p] %d{HH:mm:ss.SSS} [%15.15t] (%20.20c)  (%-10.20l) - %-20.20M - %m%n"
							  ) );

		// log4cxx::rolling::RollingFileAppender * rollingFileAppender (new log4cxx::rolling::RollingFileAppender(layout ,
		// "arkhe-gcs.log" ,
		// true));
		// rollingFileAppender->setMaxFileSize("10MB");
		// rollingFileAppender->setMaxBackupIndex(10);

		log4cxx::ConsoleAppenderPtr consoleAppender( new log4cxx::ConsoleAppender( layout ) );
		log4cxx::FileAppender * fileAppender = new log4cxx::FileAppender( log4cxx::LayoutPtr(layout ),"cfs.log",
		                                                                  false );

		log4cxx::helpers::Pool pool;
		consoleAppender->activateOptions( pool );
		log4cxx::BasicConfigurator::configure( log4cxx::AppenderPtr( fileAppender ) );
		log4cxx::BasicConfigurator::configure( consoleAppender );

		// log4cxx::BasicConfigurator::configure(log4cxx::AppenderPtr(rollingFileAppender));
		log4cxx::Logger::getRootLogger( )->setLevel( /*LOG-ALL*/ true ? log4cxx::Level::getTrace( ) : log4cxx::Level::getInfo() );

		log4cxx::LogManager::getLoggerRepository( )->setConfigured( true );

		// log4cxx::LogManager::getLoggerRepository()->getRootLogger()->info("Internal log configured");
		// log4cxx::LogManager::getLoggerRepository()->getRootLogger()->info("Starting the logging system - BASIC");
	}
	else
	{
		if( ::access( configurationPath.c_str( ), R_OK ) == 0 )
		{
#if APR_HAS_THREADS
			this->loadConfigAndWatch(log4cxx::File( configurationPath.c_str( )).getPath( ));
#else
			this->loadConfig(log4cxx::File( configurationPath.c_str( )).getPath( ));
#endif
		}

		log4cxx::Logger::getRootLogger( )->setLevel( log4cxx::Level::getAll( ) );
		log4cxx::LogManager::getLoggerRepository( )->setConfigured( true );

		// log4cxx::LogManager::getLoggerRepository()->getRootLogger()->trace("Starting the logging system" + configurationPath );
		// LOG4CXX_TRACE(log4cxx::Logger::getRootLogger(),"Logger initialized. Appenders sise:" << log4cxx::Logger::getRootLogger()->getAllAppenders().size() );
	}

	LOG4CXX_INFO( log4cxx::Logger::getRootLogger( ), "----START LOGGING-----" );
	LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ),"Logger initialized. Appenders sise:" <<
	               log4cxx::Logger::getRootLogger( )->getAllAppenders( ).size( ) );
}

LoggerPrivate::~LoggerPrivate( )
{
	LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ), __LOG4CXX_FUNC__ );

	if( log4cxx::LogManager::getLoggerRepository( )->isConfigured( ) )
	{
		LOG4CXX_INFO( log4cxx::Logger::getRootLogger( ), "---- END LOGGING -----" );
	}

	log4cxx::LogManager::shutdown( );
}

unsigned long
LoggerPrivate::periodicalCheck( ) const
{
	return (this->m_watchPeriod);
}

void
LoggerPrivate::loggerReset( )
{
	LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ), __LOG4CXX_FUNC__ );
	log4cxx::LogManager::resetConfiguration( );
	log4cxx::BasicConfigurator::resetConfiguration( );
}

std::string
LoggerPrivate::getFileExtension( const std::string & s )
{
	LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ), __LOG4CXX_FUNC__ );
	size_t i = s.rfind( '.', s.length( ) );

	if( i != std::string::npos )
	{
		return (s.substr( i + 1, s.length( ) - i ) );
	}

	return ("");
}

log4cxx::LoggerPtr
LoggerPrivate::getLoggerByName( const char * loggerName )
{
	LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ), __LOG4CXX_FUNC__ );

	return (log4cxx::LogManager::getLoggerRepository( )->getLogger( std::string( loggerName ) ) );
}

void
LoggerPrivate::loadConfig( const std::string & configFilename )
{
	if( log4cxx::LogManager::getLoggerRepository( )->isConfigured( ) )
	{
		if( !configFilename.empty( ) )
		{
			if( configFilename.find( ".xml" ) != std::string::npos )
			{
				log4cxx::xml::DOMConfigurator::configure( configFilename );
				// log4cxx::xml::DOMConfigurator::configure( log4cxx::File( configFilename ).getPath( ) );
			}
			else
			{
				log4cxx::PropertyConfigurator::configure( configFilename );
			}
		}
	}
	else
	{
		LOG4CXX_WARN( log4cxx::Logger::getRootLogger( ), "log4cxx configuration detected." );
	}
}

void
LoggerPrivate::loadConfigAndWatch( const std::string & configFilename )
{
	if( log4cxx::LogManager::getLoggerRepository( )->isConfigured( ) )
	{
		if( !configFilename.empty( ) )
		{
			if( configFilename.find( ".xml" ) != std::string::npos )
			{
				log4cxx::xml::DOMConfigurator::configureAndWatch( configFilename, static_cast< long >(this->periodicalCheck( ) ));
			}
			else
			{
				log4cxx::PropertyConfigurator::configureAndWatch( configFilename, static_cast< long >(this->periodicalCheck( ) ));
			}
		}
	}
	else
	{
		LOG4CXX_WARN( log4cxx::Logger::getRootLogger( ), "log4cxx configuration detected." );
	}
}

void
LoggerPrivate::loggerNames( std::vector<std::string> & names )
{
	log4cxx::LoggerList list = log4cxx::LogManager::getCurrentLoggers( );
	log4cxx::LoggerList::iterator logger = list.begin( );
	names.clear( );

	for(; logger != list.end( ); logger++ )
	{
		LOG4CXX_TRACE( log4cxx::Logger::getRootLogger( ), "Logger "
		               << std::distance(list.begin(), logger) << (*logger)->getName( ) );
		names.push_back( (*logger)->getName( ) );
	}
}
