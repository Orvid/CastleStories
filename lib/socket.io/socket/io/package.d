module socket.io;

import arsd.jsvar;

import std.base64 : Base64URL;
import std.conv : to;
import std.datetime : msecs, seconds;
import std.event : Event;
import std.random : uniform;
import std.serialization.json;

import vibe.core.core : runTask, sleep;
import vibe.core.log;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.router : HTTPRouter;
import vibe.http.websockets : handleWebSockets, WebSocket;
import vibe.utils.array : FixedRingBuffer;

final class SocketServer
{
private:
	enum MaxQueuedSessionMessages = 1024;
	enum SupportedProtocolVersion = "1";
	enum DefaultNamespace = "socket.io";
	enum HeartbeatTimeout = "5";
	enum DisconnectTimeout = "5";
	enum SupportedTransports = "websocket"; // websocket,flashsocket,xhr-polling,xhr-multipart,htmlfile,jsonp-polling

	final static class Session
	{
		SocketServer parent;
		bool valid;
		string sessionID;
		SocketConnection[string] activeConnections;
		FixedRingBuffer!(Message, MaxQueuedSessionMessages) messagesToSend;
		HTTPServerRequest handshake;

		this(string sessionID, SocketServer parent)
		{
			this.sessionID = sessionID;
			this.parent = parent;
			this.valid = true;
			this.enqueueMessage(Message(MessageType.connect, "", ""));
			//this.enqueueMessage(Message(MessageType.event, "", `{"name":"connect","args":[]}`));
		}

		void enqueueMessage(Message msg)
		{
			logInfo("Sending message to %s: %s", sessionID, msg.toString());
			messagesToSend.put(msg);
		}

		private void delegate(var[]) callbackFor(Message msg)
		{
			return (args) {
				auto rmsg = Message(MessageType.acknowledge, "", to!string(msg.messageID) ~ (args.length > 0 ? "+" ~ toJSON(cast(var)args) : ""));
				logInfo("Sending acknowledgement for msg: %s", rmsg);
				enqueueMessage(rmsg);
			};
		}

		void handleMessage(Message msg)
		{
			logInfo("Handling a message: %s", msg.toString());
			switch (msg.type)
			{
				case MessageType.event:
				case MessageType.acknowledge:
					logError("Woops, these currently aren't handled....");
					break;

				case MessageType.jsonMessage:
					if (auto conn = msg.endpoint in activeConnections)
						(*conn).message(fromJSON!var(msg.data), callbackFor(msg));
					break;

				case MessageType.heartbeat:
					// TODO: Need to deal with timeouts here.
					enqueueMessage(msg);
					break;

				case MessageType.message:
					if (auto conn = msg.endpoint in activeConnections)
						(*conn).message(cast(var)msg.data, callbackFor(msg));
					break;
				case MessageType.connect:
					if (msg.endpoint != "")
					{
						if (msg.endpoint in activeConnections)
							goto PutBack; // They're already connected, do nothing.
						// TODO: May need to do a bit of locking here.
						if (auto end = msg.endpoint in parent.endpoints)
							activeConnections[msg.endpoint] = new SocketConnection(*end, this);
					}
					// Otherwise it's part of the handshake, nothing special.
				PutBack:
					enqueueMessage(msg);
					break;
				case MessageType.disconnect:
					if (msg.endpoint != "")
					{
						if (auto conn = msg.endpoint in activeConnections)
							(*conn).disconnect();
						// Otherwise we've already disconnected from it, so do nothing.
					}
					else
					{
						parent.sessions.remove(sessionID);
						this.valid = false;
						foreach (k, sc; activeConnections)
							sc.disconnect();
					}
					break;
				case MessageType.nop:
					break;
				case MessageType.error:
					// As the server, we shouldn't recieve this.
					logError("What is this madness?!?!?! We recieved an error message from the client.");
					break;
				default:
					break;
			}
		}
	}

	enum MessageType
	{
		unknown = -1,

		disconnect = 0,
		connect = 1,
		heartbeat = 2,
		message = 3,
		jsonMessage = 4,
		event = 5,
		acknowledge = 6,
		error = 7,
		nop = 8,
	}

	static struct Message
	{
		MessageType type;
		size_t messageID;
		bool userHandledACK;
		string endpoint;
		string data;

		this(MessageType type, string endpoint, string data, size_t messageID = size_t.max, bool userACK = false) inout @safe pure nothrow
		{
			this.type = type;
			this.endpoint = endpoint;
			this.data = data;
			this.messageID = messageID;
			this.userHandledACK = userACK;
		}

		string toString() inout @safe pure
		{
			string str = to!string(cast(int)type) ~ ":";
			if (messageID != size_t.max)
				str ~= to!string(messageID);
			if (userHandledACK)
				str ~= "+";
			return str ~ ":" ~ endpoint ~ ":" ~ data;
		}

		static Message parse(string str) pure
		{
			import std.array : findSplit;

			auto v = findSplit(str, ":");
			uint type = to!int(v[0]);
			v = findSplit(v[2], ":");
			size_t id = size_t.max;
			bool userACK = false;
			if (v[0] != "")
			{
				if (v[0][$-1] == '+')
					userACK = true;
				id = to!size_t(v[0][0..userACK ? $ - 1 : $]);
			}
			v = findSplit(v[2], ":");

			return Message(cast(MessageType)type, v[0], v[2], id, userACK);
		}
	}

	Session[string] sessions;

	void newSessionHandler(HTTPServerRequest req, HTTPServerResponse res)
	{
		string sessionID = void;
	CreateID:
		// The original socket.io server uses a 15-character ID, but this should be
		// the fastest way to produce a random session ID for base64 encoding.
		ubyte[size_t.sizeof * 3] buf;
		*cast(size_t*)&buf.ptr[size_t.sizeof * 0] = uniform(size_t.min, size_t.max);
		*cast(size_t*)&buf.ptr[size_t.sizeof * 1] = uniform(size_t.min, size_t.max);
		*cast(size_t*)&buf.ptr[size_t.sizeof * 2] = uniform(size_t.min, size_t.max);

		sessionID = cast(string)Base64URL.encode(buf);
		synchronized
		{
			if (sessionID in sessions)
				goto CreateID;
			sessions[sessionID] = new Session(sessionID, this);
		}
		res.writeBody(sessionID ~ ':' ~ HeartbeatTimeout ~ ':' ~ DisconnectTimeout ~ ':' ~ SupportedTransports);
	}


	void transportHandler(HTTPServerRequest req, HTTPServerResponse res)
	{
		if (auto sessionP = req.params["sessionID"] in sessions)
		{
			Session session = *sessionP;
			session.handshake = req;
			switch (req.params["transportID"])
			{
				case "websocket":
					handleWebSockets((WebSocket socket) {
						runTask({
							while (true)
							{
								socket.waitForData(10.seconds);
								if (!socket.connected || !session.valid)
									break;
								else if (socket.dataAvailableForRead)
									session.handleMessage(Message.parse(socket.receiveText()));
							}
						});
						while (true)
						{
							// TODO: messagesToSend needs to be worked with synchronously here...
							while (session.messagesToSend.length)
							{
								if (!socket.connected)
								{
									logInfo("Socket disconnected!");
									goto Exit;
								}
								else if (!session.valid)
								{
									logInfo("Session invalid!");
									goto Exit;
								}
								socket.send(session.messagesToSend.front.toString());
								session.messagesToSend.popFront();
							}
							sleep(10.msecs);
						}
					Exit:
						logInfo("%s Socket sending finished.", req.params["sessionID"]);
						session.valid = false;
						return;
					})(req, res);
					break;

				default:
					logError("Unknown transportID '%s'", req.params["transportID"]);
					break;
			}
		}
		// Otherwise the socket already timed out, so we'll just ignore this connection.
	}

public:
	final static class Endpoint
	{
	package:
		SocketConnection[] activeConnections;
		string name;
		Event!(void delegate(SocketConnection connection)) connect;
		Event!(void delegate(SocketConnection connection)) disconnect;

		this()
		{
			import std.algorithm : remove;

			connect ~= (conn) {
				activeConnections ~= conn;
			};

			disconnect ~= (conn) {
				activeConnections = activeConnections.remove!(c => c == conn);
			};
		}

	public:
		void sendJSON(var msg, SocketConnection exceptFor = null)
		{
			foreach (c; activeConnections)
			{
				if (c != exceptFor)
					c.sendJSON(msg);
			}
		}

		void trigger(string eventName, var[] args...)
		{
			foreach (c; activeConnections)
				c.trigger(eventName, args);
		}
	}

	final static class SocketConnection
	{
	private:
		bool valid = true;
		Endpoint attachedEndpoint;
		Session parentSession;

	package:
		this(Endpoint endpoint, Session parent)
		{
			attachedEndpoint = endpoint;
			parentSession = parent;
			disconnect ~= () {
				valid = false;
				parentSession.enqueueMessage(Message(MessageType.disconnect, attachedEndpoint.name, ""));
			};
			message ~= (msg, callback) {
				logInfo("Broadcasting message %s", msg);
			};
			attachedEndpoint.connect(this);
		}

	public:
		Event!(void delegate()) disconnect;
		Event!(void delegate(var message, void delegate(var[]) callbackFn)) message;

		@property auto handshake() const { return parentSession.handshake; }
		@property auto endpoint() { return attachedEndpoint; }

		void sendJSON(var msg)
		{
			if (valid)
				parentSession.enqueueMessage(Message(MessageType.jsonMessage, attachedEndpoint.name, toJSON(msg)));
		}

		void send(string message)
		{
			if (valid)
				parentSession.enqueueMessage(Message(MessageType.message, attachedEndpoint.name, message));
		}

		void trigger(string eventName, var[] args)
		{
			if (valid)
				parentSession.enqueueMessage(Message(MessageType.event, attachedEndpoint.name, `{"name":"` ~ eventName ~ `","args":` ~ toJSON(cast(var)args) ~ `}`));
		}
	}

	Endpoint[string] endpoints;

	this(scope HTTPRouter router)
	{
		router.get("/" ~ DefaultNamespace ~ "/" ~ SupportedProtocolVersion ~ "/", &newSessionHandler);
		router.get("/" ~ DefaultNamespace ~ "/" ~ SupportedProtocolVersion ~ "/:transportID/:sessionID", &transportHandler);
	}

	Endpoint getEndpoint(string name)
	{
		if (name !in endpoints)
			endpoints[name] = new Endpoint();
		return endpoints[name];
	}

	SocketServer endpoint(scope string path, void delegate(SocketConnection conn) connectionHandler)
	{
		if (path !in endpoints)
			endpoints[path] = new Endpoint();
		endpoints[path].connect ~= connectionHandler;
		return this;
	}
}

alias Endpoint = SocketServer.Endpoint;
alias SocketConnection = SocketServer.SocketConnection;
