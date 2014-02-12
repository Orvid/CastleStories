module vibe.extensions.murmur3;

void murmurHash3_128(in ubyte[] key, out ulong[2] dest, uint seed = 0) @trusted pure nothrow
{
	static ulong getblock(in ubyte[] p, size_t i) @safe pure nothrow
	{
		import std.bitmanip : endian, read;

		auto tmp = p[i * ulong.sizeof..$];
		return 
			  tmp[0] << 7 
			| tmp[1] << 6
			| tmp[2] << 5
			| tmp[3] << 4
			| tmp[4] << 3
			| tmp[5] << 2
			| tmp[6] << 1
			| tmp[7]
		;
	}
	static ulong fmix64(ulong k) @safe pure nothrow
	{
		k ^= k >> 33;
		k *= 0xFF51AFD7ED558CCD;
		k ^= k >> 33;
		k *= 0xC4CEB9FE1A85EC53;
		k ^= k >> 33;
		return k;
	}
	
	static ulong rotl64(ulong x, ubyte r) @safe pure nothrow
	{
		return (x << r) | (x >> (64 - r));
	}

	immutable nblocks = key.length / 16;

	ulong h1 = seed;
	ulong h2 = seed;
	
	enum ulong c1 = 0x87c37b91114253d5;
	enum ulong c2 = 0x4cf5ad432745937f;

	for(size_t i = 0; i < nblocks; i++)
	{
		ulong k1 = getblock(key, i * 2);
		ulong k2 = getblock(key, i * 2 + 1);
		
		k1 *= c1; k1  = rotl64(k1,31); k1 *= c2; h1 ^= k1;
		
		h1 = rotl64(h1,27); h1 += h2; h1 = h1*5+0x52dce729;

		k2 *= c2; k2  = rotl64(k2,33); k2 *= c1; h2 ^= k2;

		h2 = rotl64(h2,31); h2 += h1; h2 = h2*5+0x38495ab5;
	}

	auto tail = key[nblocks * 16..$];

	ulong k1 = 0;
	ulong k2 = 0;

	switch (key.length & 15)
	{
		case 15: k2 ^= (cast(ulong)tail[14]) << 48;
		case 14: k2 ^= (cast(ulong)tail[13]) << 40;
		case 13: k2 ^= (cast(ulong)tail[12]) << 32;
		case 12: k2 ^= (cast(ulong)tail[11]) << 24;
		case 11: k2 ^= (cast(ulong)tail[10]) << 16;
		case 10: k2 ^= (cast(ulong)tail[ 9]) << 8;
		case  9: k2 ^= (cast(ulong)tail[ 8]) << 0;
			k2 *= c2; k2  = rotl64(k2,33); k2 *= c1; h2 ^= k2;
			
		case  8: k1 ^= (cast(ulong)tail[ 7]) << 56;
		case  7: k1 ^= (cast(ulong)tail[ 6]) << 48;
		case  6: k1 ^= (cast(ulong)tail[ 5]) << 40;
		case  5: k1 ^= (cast(ulong)tail[ 4]) << 32;
		case  4: k1 ^= (cast(ulong)tail[ 3]) << 24;
		case  3: k1 ^= (cast(ulong)tail[ 2]) << 16;
		case  2: k1 ^= (cast(ulong)tail[ 1]) << 8;
		case  1: k1 ^= (cast(ulong)tail[ 0]) << 0;
			k1 *= c1; k1  = rotl64(k1,31); k1 *= c2; h1 ^= k1;
		default:
			break;
	}

	h1 ^= key.length; h2 ^= key.length;

	h1 += h2;
	h2 += h1;

	h1 = fmix64(h1);
	h2 = fmix64(h2);

	h1 += h2;
	h2 += h1;

	dest[0] = h1;
	dest[1] = h2;
}