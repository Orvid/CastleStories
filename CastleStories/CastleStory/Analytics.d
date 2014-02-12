module CastleStory.Analytics;

import arsd.jsvar;

import CastleStory.Analyst;

import socket.io;

import std.event;

import vibe.core.log;

final class Analytics
{
private:
	uint maxRT;
	uint rtCount = 0;
	Endpoint domain;

public:
	Event!(void delegate(Analyst analyst)) RTConnect;
	Event!(void delegate(Analyst analyst)) RTDisplay;

	this(uint maxRT, Endpoint domain)
	{
		this.maxRT = maxRT;
		this.domain = domain;

		RTConnect ~= (analyst) {
			logDebug("Analytics.RTConnect with analyst %s", analyst);
		};

		RTDisplay ~= (analyst) {
			analyst.Broadcast ~= (message, ignoreSelf) {
				analyst.domain.trigger(message);
			};
		};
	}

	void emit(string signal, var data)
	{
		logDebug("Analytics.emit() signal: %s, data: %s", signal, data);
		domain.trigger(signal, data);
	}
}

