module CastleStory.Config;

static struct Configuration
{
	/++
	 + The time to delay responding to 
	 + every message, in milliseconds.
	 +/
	size_t latency = 0;
	uint gameCount = 1;
	uint maxPlayers = 1;//4;
	uint maxObservers = 1;
	bool metricsEnabled = true;
	string mapsPath = "../maps";
	ushort port = 8080;
}
__gshared config = Configuration();