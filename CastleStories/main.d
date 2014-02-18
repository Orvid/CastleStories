module main;

import CastleStory.Analyst;
import CastleStory.Analytics;
import CastleStory.CastleServer;
import CastleStory.Config;
import CastleStory.Observer;
import CastleStory.Player;

import socket.io;

import vibe.core.core : sleep;
import vibe.core.log;
import vibe.extensions;
import vibe.http.fileserver;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets;

import CastleStory.stubs;

@property URLRouter view(string menu, string submenu)(URLRouter router)
{
	import std.serialization.core : serializable;
	import std.serialization.json : fromJSON;
	import vibe.extensions.slim;

	@serializable static struct Version
	{
		size_t major;
		size_t minor;
		size_t release;
		string release_name;
		string rev;

		string toString()
		{
			import std.conv : to;

			return release_name ~ " " ~ release.to!string() ~ "." ~ major.to!string() ~ "." ~ minor.to!string() ~ "." ~ rev;
		}
	}

	enum title = "CastleStory/MP";
	enum versionInfo = fromJSON!Version(import("version.json")).toString();
	enum string[] extrajsFiles = [
		"/js/socket.io/socket.io.min.js",
		"/js/highcharts.min.js",
		"/js/realtime.js",
	];

	static if (menu == "home")
		enum webPath = "";
	else
		enum webPath = menu ~ (submenu != "" ? "/" ~ submenu : "");
	enum filePath = webPath ~ (submenu != "" ? "" : "/index") ~ ".st";
	router.get("/" ~ webPath, &slimTemplate!(filePath, title, menu, submenu, extrajsFiles, versionInfo));
	//slimTemplate!(filePath, title, menu, submenu, extrajsFiles, versionInfo)(null, null);
	return router;
}


shared static this()
{
	setLogLevel(LogLevel.debug_);
	logInfo("Starting up the Castle Story Multiplayer Server");
	Analytics analytics = null;
	CastleServer[] games;

	auto router = new URLRouter();
	auto socket = new SocketServer(router);
	
	if (config.metricsEnabled)
		analytics = new Analytics(2, socket.getEndpoint("/analytics"));

	foreach (i; 0..config.gameCount)
	{
		auto g = new CastleServer(i, config.maxPlayers, config.maxObservers, analytics);
		g.run(config.mapsPath);
		games ~= g;
	}

	socket
		.endpoint("/play", (conn) {
			logInfo("%s connected to /play", conn.handshake.peer);
			conn.disconnect ~= () {
				logInfo("%s disconnected from /play", conn.handshake.peer);
			};

			CastleServer game = games.where!(g => g.playerCount < g.maxPlayers).firstOrDefault();
			// TODO: Provide some sort of error if all games are full.
			game.updatePopulation();
			auto p = new Player(conn, socket.endpoints["/play"], game);
			game.PlayerConnect(p);
		})
		.endpoint("/watch", (conn) {
			logInfo("%s connected to /watch", conn.handshake.peer);
			conn.disconnect ~= () {
				logInfo("%s disconnected from /watch", conn.handshake.peer);
			};

			CastleServer game = games.where!(g => g.observerCount < g.maxObservers).firstOrDefault();
			game.updatePopulation();
			auto o = new Observer(conn, socket.endpoints["/watch"], game);
			game.ObserverConnect(o);
		})
		.endpoint("/analytics", (conn) {
			logInfo("%s connected to /analytics", conn.handshake.peer);
			analytics.RTConnect(new Analyst(conn, socket.endpoints["/analytics"], analytics));

			conn.disconnect ~= () {
				logInfo("%s disconnected from /analytics", conn.handshake.peer);
			};
		})
	;

	router
		.file!"favicon.ico"
		//.file!"favicon.png"
		.file!"css/bootstrap.min.css"
		.file!"css/style.css"
		.file!"img/bg_left_white.gif"
		.file!"img/bg_pattern.jpg"
		.file!"img/cc_active_nav.png"
		.file!"img/glyphicons-halflings.png"
		.file!"img/glyphicons-halflings-white-nav.png"
		.file!"img/glyphicons-halflings-white-shadow.png"
		//.file!"js/socket.io/socket.io.js"
		.file!"js/socket.io/socket.io.min.js"
		.file!"js/socket.io/WebSocketMain.swf"
		.file!"js/socket.io/WebSocketMainInsecure.swf"
		//.file!"js/bootstrap.js"
		.file!"js/bootstrap.min.js"
		.file!"js/date.format.js"
		.file!"js/highcharts.min.js"
		.file!"js/jquery.autosize-min.js"
		.file!"js/jquery-1.8.3.min.js"
		.file!"js/realtime.js"
		.file!"js/script.js"
		.file!"js/sortables.js"
		.view!("home", "")
		.view!("auth", "admins")
		.view!("auth", "server")
		.view!("entities", "blocks")
		.view!("entities", "spawned")
		.view!("maps", "")
		.view!("realtime", "overview")
		.view!("sessions", "current")
		.view!("sessions", "persistent")
		.view!("sessions", "recorded")
		.view!("settings", "games")
		.view!("settings", "server")
		.view!("users", "observers")
		.view!("users", "players")
	;

	auto settings = new HTTPServerSettings();
	settings.accessLogToConsole = true;
	settings.port = config.port;
	settings.bindAddresses = ["::1", "127.0.0.1", "192.168.4.121"];
	settings.options |= HTTPServerOption.distribute;
	listenHTTP(settings, router);
}
