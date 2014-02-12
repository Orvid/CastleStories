module CastleStory.stubs;

// TODO: Add a constraint for the constraint paramter.
auto where(alias constraint, T)(inout scope T[] input) 
{
	// TODO: This needs to be returning a lazy range.
	T[] dest = new T[input.length];
	size_t i = 0;
	foreach (e; input)
	{
		if (constraint(e))
		{
			dest[i] = cast(T)e;
			i++;
		}
	}
	dest.length = i;

	return dest;
}
auto firstOrDefault(T)(inout scope T[] input) { return input.length ? input[0] : T.init; }

auto toArray(T)(T[] input)
{
	return input;
}
