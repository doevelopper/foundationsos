#ifndef CPPBDD101_INTERFACE_HPP
#define CPPBDD101_INTERFACE_HPP

class Interface
{
enum State
{
	STOPPED,
	PLAYING,
	PAUSED
};

State m_state;

public:
virtual void play() = 0;
virtual void stop() = 0;
virtual void pause() = 0;
virtual int state() const = 0;
};
#endif

