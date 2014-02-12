module vibe.extensions;

import vibe.core.log;
import vibe.http.fileserver;
import vibe.http.router : URLRouter;
import vibe.http.server;

@property URLRouter file(string filePath)(URLRouter router)
{
	router.get("/" ~ filePath, &serveStaticFile!filePath);
	return router;
}


void serveStaticFile(string filePath)(HTTPServerRequest req, HTTPServerResponse res)
{
	import vibe.core.file;
	import vibe.inet.message;
	import vibe.inet.mimetypes;
	import vibe.extensions.murmur3;
	import std.conv;
	import std.datetime : Clock, UTC, seconds;

	// TODO: Currently this treats the build machine's clock as if it
	//       was in the GMT timezone, which is likely incorrect.
	template currentTimeAsRFC822DateTimeString()
	{
		enum dayOfWeek = __TIMESTAMP__[0..3];
		enum month = __TIMESTAMP__[4..7];
		enum dayOrig = __TIMESTAMP__[8..10];
		enum day = dayOrig[0] == ' ' ? "0" ~ dayOrig[1] : dayOrig;
		enum year = __TIMESTAMP__[20..$];

		enum currentTimeAsRFC822DateTimeString = dayOfWeek ~ ", " ~ day ~ " " ~ month ~ " " ~ year ~ " " ~ __TIME__ ~ " GMT";
		//assert(SysTime.fromSimpleString("2010-Jul-04 07:06:12")
		//fromSimpleString("Thu Dec 5 10:28:04 2013", null)
		//Dec  5 2013
	}
	
	enum fileData = import(filePath);
	HTTPFileServerSettings settings = new HTTPFileServerSettings();
	enum lastModified = currentTimeAsRFC822DateTimeString!();
	// simple etag generation
	static string buildHash(ubyte[] input)
	{
		ulong[2] data;
		murmurHash3_128(input, data);
		return to!string(data[0], 16) ~ to!string(data[1], 16);
	}
	enum etag = "\"" ~ buildHash(cast(ubyte[])(filePath ~ ":" ~ lastModified ~ ":" ~ to!string(fileData.length))) ~ "\"";
	
	res.headers["Last-Modified"] = lastModified;
	res.headers["Etag"] = etag;
	if (settings.maxAge > seconds(0))
	{
		auto expireTime = Clock.currTime(UTC()) + settings.maxAge;
		res.headers["Expires"] = toRFC822DateTimeString(expireTime);
		res.headers["Cache-Control"] = "max-age=" ~ to!string(settings.maxAge.total!"seconds");
	}
	
	if(auto pv = "If-Modified-Since" in req.headers)
	{
		if(*pv == lastModified)
		{
			res.statusCode = HTTPStatus.NotModified;
			res.writeVoidBody();
			return;
		}
	}
	
	if(auto pv = "If-None-Match" in req.headers )
	{
		if (*pv == etag)
		{
			res.statusCode = HTTPStatus.NotModified;
			res.writeVoidBody();
			return;
		}
	}
	
	// TODO: I removed the pre-compressed encoding capibility, it should be re-added.
	enum mimetype = getMimeTypeForFile(filePath);
	enum isCompressedMimeType = isCompressedFormat(mimetype);
	enum fileDataLengthString = to!string(fileData.length);
	// avoid double-compression
	if ("Content-Encoding" in res.headers && isCompressedMimeType)
		res.headers.remove("Content-Encoding");
	res.headers["Content-Type"] = mimetype;
	res.headers["Content-Length"] = fileDataLengthString;
	
	// TODO: I removed the pre-write callback
	
	// for HEAD responses, stop here
	if(res.isHeadResponse())
	{
		res.writeVoidBody();
		assert(res.headerWritten);
		logDebug("sent file header %d, %s!", fileData.length, res.headers["Content-Type"]);
		return;
	}
	
	if ("Content-Encoding" in res.headers)
		res.bodyWriter.write(fileData);
	else
		res.writeRawBody(fileData);
	logTrace("sent file %d, %s!", fileData.length, res.headers["Content-Type"]);
}