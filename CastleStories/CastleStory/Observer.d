module CastleStory.Observer;

import arsd.jsvar;

import CastleStory.CastleServer;
import CastleStory.Entity;
import CastleStory.Messages;

import socket.io;

import std.conv;
import std.event;
import std.string;

import vibe.core.log;

@scriptable
class Observer : Entity
{
private:
	SocketConnection mSocket;
	Endpoint mDomain;
	CastleServer mServer;

protected:
	bool mHasEnteredGame;
	size_t mIndex;
	string mName;

	string mIP;


public:
	@property bool hasEnteredGame() const { return mHasEnteredGame; }
	@property size_t index() const { return mIndex; }
	@property string name() const { return mName; }
	@property auto socket() { return mSocket; }

	Event!(void delegate(string msg, var props)) Analytics;
	Event!(void delegate(Message msg, bool ignoreSelf = true)) Broadcast;
	Event!(void delegate()) Exit;
	Event!(void delegate(var message, var callbackFn)) UnhandledMessage;

	this(this T)(SocketConnection socket, Endpoint domain, CastleServer server)
	{
		auto nID = server.getID();
		super(nID, nID); // We belong to ourself.
		this.mSocket = socket;
		this.mDomain = domain;
		this.mServer = server;

		// Because D is awesome, we can determine at compile time if
		// this constructor is being called for an Observer, or for a
		// Player.
		static if (is(T == Observer))
		{
			logDebug("Observer unique id: %s", network_id);

			socket.message ~= (message, callbackFn) {
				logDebug("Observer.onMessage: message: %s", message);

				MessageType action = cast(MessageType)cast(uint)message[0];
				switch(action)
				{
					case MessageType.Hello:
						logDebug("Observer.onMessage.Hello");
						this.mName = cast(string)message[1];
						this.mIndex = server.getObserverIndex();
						if (!name || name == "")
							this.mName = "Observer " ~ to!string(index + 1);
						server.addObserver(this);
						send(new Messages.Welcome(this).serialize());
						server.ObserverEnter(this);
						this.mHasEnteredGame = true;
						break;
					default:
						// TODO: Player triggers an event in this case, should we do the same here?
						logInfo("Observer recieved the unknown message: %s", message);
						break;
				}

				this.mIP = socket.handshake.peer;
				this.Analytics("messages", varObject(
					"connections", server.observerCount,
					"msg", message,
					//"observers", server.observers,
					"action", action.to!string(),
					"timestamp", format("%.3s", server.getTime().total!"seconds"),
				));
			};

			socket.disconnect ~= () {
				logDebug("Observer.socket.onDisconnect");
				Exit();
			};
		}
	}

	void send(var message)
	{
		socket.sendJSON(message);
	}

	override var getState()
	{
		return super.getState() ~ varArray(name);
	}
}

