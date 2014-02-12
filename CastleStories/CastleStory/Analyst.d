module CastleStory.Analyst;

import CastleStory.Analytics;

import socket.io;

import std.event;

import vibe.core.log;

import CastleStory.stubs;

final class Analyst
{
private:
	SocketConnection socket;
	Endpoint mDomain;
	Analytics analytics;

public:
	Event!(void delegate()) Exit;
	Event!(void delegate(string message, bool ignoreSelf = true)) Broadcast;

	auto ref @property domain() { return mDomain; }

	this(SocketConnection socket, Endpoint domain, Analytics analytics)
	{
		logDebug("Analyst.init");
		this.socket = socket;
		this.domain = domain;
		this.analytics = analytics;

		socket.disconnect ~= () {
			logDebug("Analyst.on.Disconnect");
			this.Exit();
		};
	}
}

