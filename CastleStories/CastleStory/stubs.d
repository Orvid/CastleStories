module CastleStory.stubs;

auto firstOrDefault(T)(scope T input) 
{
	import std.array : empty, front;
	import std.traits : ForeachType;

	return input.empty ? ForeachType!T.init : input.front;
}
