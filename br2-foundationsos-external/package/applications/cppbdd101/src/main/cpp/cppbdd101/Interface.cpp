#include <cppbdd101/Interface.hpp>

void Interface::play()
{
	m_state = PLAYING;
}

void Interface::stop()
{
	m_state = STOPPED;
}

void Interface::pause()
{
	m_state = PAUSED;
}
