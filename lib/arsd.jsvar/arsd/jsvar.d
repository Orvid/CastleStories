// This file has been HEAVILY modified by Orvid.

/**
	jsvar provides a D type called 'var' that works similarly to the same in Javascript.

	It is weakly and dynamically typed, but interops pretty easily with D itself:

	var a = 10;
	a ~= "20";
	assert(a == "1020");

	var a = function(int b, int c) { return b+c; };
	// note the second set of () is because of broken @property
	assert(a()(10,20) == 30);

	var a = var.emptyObject;
	a.foo = 30;
	assert(a["foo"] == 30);

	var b = json!q{
		"foo":12,
		"bar":{"hey":[1,2,3,"lol"]}
	};

	assert(b.bar.hey[1] == 2);


	You can also use var.fromJson, a static method, to quickly and easily
	read json or var.toJson to write it.

	Also, if you combine this with my new arsd.script module, you get pretty
	easy interop with a little scripting language that resembles a cross between
	D and Javascript - just like you can write in D itself using this type.
*/
module arsd.jsvar;

//import std.stdio;
import std.traits;
import std.conv;
import std.serialization.json;

// uda for wrapping classes
enum scriptable;


// literals

// var a = varArray(10, "cool", 2);
// assert(a[0] == 10); assert(a[1] == "cool"); assert(a[2] == 2);
var varArray(T...)(T t)
{
	var a = var.emptyArray;
	foreach(arg; t)
		a ~= var(arg);
	return a;
}

// var a = varObject("cool", 10, "bar", "baz");
// assert(a.cool == 10 && a.bar == "baz");
var varObject(T...)(T t)
{
	var a = var.emptyObject;
	
	string lastString;
	foreach(idx, arg; t)
	{
		static if(idx % 2 == 0)
		{
			lastString = arg;
		}
		else
		{
			assert(lastString !is null);
			a[lastString] = arg;
			lastString = null;
		}
	}
	return a;
}

struct var
{
	public this(T)(T t)
	{
		static if(is(T == var))
			this = t;
		else
			this.opAssign(t);
	}

	public bool opCast(T : bool)()
	{
		final switch (this._type)
		{
			case Type.Object:
				return !this._payload._objectNull;
			case Type.Array:
				return this._payload._array.length != 0;
			case Type.String:
				return this._payload._string.length != 0;
			case Type.Integral:
				return this._payload._integral != 0;
			case Type.Floating:
				return this._payload._floating != 0;
			case Type.Boolean:
				return this._payload._boolean;
			case Type.Function:
				return this._payload._function !is null;
			case Type.WrappedObject:
				return this._payload._wrappedObject !is null;
		}
	}
	
	public int opApply(scope int delegate(ref var) dg)
	{
		foreach(i, item; this)
		{
			if(auto result = dg(item))
				return result;
		}
		return 0;
	}
	
	public int opApply(scope int delegate(var, ref var) dg)
	{
		if (this.payloadType() == Type.Array)
		{
			foreach (i, ref v; this._payload._array)
			{
				if (auto result = dg(var(i), v))
					return result;
			}
		}
		else if (this.payloadType() == Type.Object && !this._payload._objectNull)
		{
			foreach (k, ref v; this._payload._object)
			{
				if (auto result = dg(var(k), v))
					return result;
			}
		}
		else if (this.payloadType() == Type.String)
		{
			// this is to prevent us from allocating a new string on each character, hopefully limiting that massively
			static immutable string chars = makeAscii!();
			
			foreach (i, dchar c; this._payload._string)
			{
				var lol = "";
				if (c < 128)
					lol._payload._string = chars[c..c + 1];
				else
					lol._payload._string = to!string(""d ~ c); // blargh, how slow can we go?
				if (auto result = dg(var(i), lol))
					return result;
			}
		}
		// throw invalid foreach aggregate
		
		return 0;
	}
	
	
	public T opCast(T)()
	{
		return this.get!T;
	}
	
	public auto ref putInto(T)(ref T t)
	{
		return t = this.get!T;
	}
	
	// if it is var, we'll just blit it over
	public var opAssign(T)(T t)
		if (!is(T == var)) 
	{
		static if (isFloatingPoint!T)
		{
			this._type = Type.Floating;
			this._payload._floating = t;
		}
		else static if (isIntegral!T)
		{
			this._type = Type.Integral;
			this._payload._integral = cast(long)t;
		}
		else static if (isCallable!T) 
		{
			this._type = Type.Function;
			this._payload._function = delegate var(var _this, var[] args)
			{
				var ret;
				
				ParameterTypeTuple!T fargs;
				foreach (idx, a; fargs) 
				{
					if (idx == args.length)
						break;
					cast(Unqual!(typeof(a)))fargs[idx] = args[idx].get!(typeof(a));
				}
				
				static if (is(ReturnType!t == void)) 
				{
					t(fargs);
				}
				else 
				{
					ret = t(fargs);
				}
				
				return ret;
			};
		}
		else static if (isSomeString!T) 
		{
			this._type = Type.String;
			this._payload._string = to!string(t);
		}
		else static if (is(T == class))
		{
			import std.traitsExt;
			static if (isClass!T && hasAttribute!(T, scriptable))
			{
				this._type = Type.WrappedObject;
				this._payload._wrappedObject = t;
			}
			else
				static assert(0, "Unsupported.");
		}
		else static if (isAssociativeArray!T)
		{
			this._type = Type.Object;
			
			foreach(l, v; t) 
			{
				this[cast(string)l] = var(v);
			}
		}
		else static if (isArray!T)
		{
			this._type = Type.Array;
			var[] arr;
			arr.length = t.length;
			foreach(i, item; t)
				arr[i] = var(item);
			this._payload._array = arr;
		}
		else static if (is(T == bool))
		{
			this._type = Type.Boolean;
			this._payload._boolean = t;
		}
		//else
		//	static assert(0, "Cannot assign value of type " ~ T.stringof ~ " to a var!");
		
		return this;
	}

	public var opBinary(string op : "~", T)(T b)
	{
		var pm = this;
		if (payloadType() == Type.Array)
		{
			static if (isArray!T)
			{
				foreach (v; b)
					pm ~= var(v);
			}
			else
				pm ~= var(b);
			return pm;
		}
		else
			throw new Exception("Unsupported operation!");
	}

	public var opOpAssign(string op : "~", T)(T s)
	{
		if (payloadType() == Type.Array)
		{
			static if (isArray!T)
			{
				foreach (v; s)
					this._payload._array ~= var(v);
			}
			else
				this._payload._array ~= var(s);
			return this;
		}
		else
			throw new Exception("Unsupported operation!");
	}

	public var* opBinary(string op : "in", T)(T s)
	{
		var rhs = var(s);
		return rhs.opBinaryRight!"in"(this);
	}

	public var* opBinaryRight(string op : "in", T)(T s)
	{
		return var(s).get!string in this._payload._object;
	}
	
	public var apply(var _this, var[] args)
	{
		if(this.payloadType() == Type.Function)
		{
			assert(this._payload._function !is null);
			return this._payload._function(_this, args);
		}
		
		version(jsvar_throw)
			throw new DynamicTypeException(this, Type.Function);
		
		var ret;
		return ret;
	}
	
	public var call(T...)(var _this, T t)
	{
		var[] args;
		foreach (a; t)
		{
			args ~= var(a);
		}
		return this.apply(_this, args);
	}
	
	public var opCall(T...)(T t)
	{
		return this.call(this, t);
	}
	
	public string toString()
	{
		return toJSON(this);
	}
	
	public T get(T)(string file = __FILE__, int line = __LINE__)
		if (!is(T == void)) 
	{
		static if (is(T == var))
		{
			static assert(0, "Well, I would ask why you are casting a var to a var, but you should already know why...");
			return this;
		}
		else
		{
			switch (payloadType)
			{
				case Type.WrappedObject:
					static if (is(T == class))
						return cast(T)this._payload._wrappedObject;
					else static if (isSomeString!T)
					{
						if (this._payload._wrappedObject is null)
							return "null";
						return this._payload._wrappedObject.toString();
					}
					else
						goto default;
				case Type.Boolean:
					static if (is(T == bool))
						return this._payload._boolean;
					else static if (isFloatingPoint!T || isIntegral!T)
						return this._payload._boolean ? 1 : 0;
					else static if (isSomeString!T)
						return this._payload._boolean ? "true" : "false";
					else
						goto default;
				case Type.Object:
					static if (isAssociativeArray!T)
					{
						T ret;
						foreach (k, v; this._payload._object._properties)
							ret[to!(KeyType!T)(k)] = v.get!(ValueType!T);
						
						return ret;
					}
					else static if (is(T == struct) || is(T == class))
					{
						T t;
						static if (is(T == class))
							t = new T();
						else
							t = T();
						
						foreach (i, a; t.tupleof)
						{
							cast(Unqual!(typeof((a))))t.tupleof[i] = this[t.tupleof[i].stringof[2..$]].get!(typeof(a));
						}
						
						return t;
					}
					else static if (isSomeString!T)
					{
						if (!this._payload._objectNull)
							return toJSON(this._payload._object);
						return "null";
					}
					goto default;
				case Type.Integral:
					static if (isFloatingPoint!T || isIntegral!T)
						return to!T(this._payload._integral);
					else static if (isSomeString!T)
						return to!string(this._payload._integral);
					else
						goto default;
				case Type.Floating:
					static if (isFloatingPoint!T || isIntegral!T)
						return to!T(this._payload._floating);
					else static if (isSomeString!T)
						return to!string(this._payload._floating);
					else
						goto default;
				case Type.String:
					static if (__traits(compiles, to!T(this._payload._string)))
					{
						try
						{
							return to!T(this._payload._string);
						} 
						catch (Exception e) {}
					}
					goto default;
				case Type.Array:
					import std.range : ElementType;

					auto pl = this._payload._array;
					static if (isSomeString!T)
						return to!string(pl);
					else static if (isArray!T)
					{
						T ret;
						static if (is(ElementType!T == void))
							static assert(0, "try wrapping the function to get rid of void[] args");
						else
							alias getType = ElementType!T;
						foreach (item; pl)
							ret ~= item.get!(getType);
						return ret;
					}
					else
						goto default;
				case Type.Function:
					static if (isSomeString!T)
						return "<function>";
					else
						goto default;
				
				default:
					throw new Exception("Unsupported operation for get!", file, line);
			}
		}
	}
	
	public bool opEquals(T)(T t)
	{
		return this.opEquals(var(t));
	}
	
	public bool opEquals(T : var)(T t) 
	{
		if(this._type != t._type)
			return false;
		final switch(this._type) 
		{
			case Type.WrappedObject:
				return _payload._wrappedObject is t._payload._wrappedObject;
			case Type.Object:
				return _payload._object is t._payload._object;
			case Type.Integral:
				return _payload._integral == t._payload._integral;
			case Type.Boolean:
				return _payload._boolean == t._payload._boolean;
			case Type.Floating:
				return _payload._floating == t._payload._floating;
			case Type.String:
				return _payload._string == t._payload._string;
			case Type.Function:
				return _payload._function is t._payload._function;
			case Type.Array:
				return _payload._array == t._payload._array;
		}
		assert(0);
	}
	
	public enum Type
	{
		Object,
		Array, 
		Integral,
		Floating,
		String,
		Function,
		Boolean,
		WrappedObject
	}
	
	public Type payloadType()
	{
		return _type;
	}
	
	private Type _type;
	
	private union Payload
	{
		var[string] _object;
		var[] _array;
		long _integral;
		real _floating;
		string _string;
		bool _boolean;
		var delegate(var _this, var[] args) _function;
		Object _wrappedObject;

		@property bool _objectNull() const { return _object.length == 0; }
	}
	
	package Payload _payload;

	public @property bool isTypeBoolean() { return payloadType() == Type.Boolean; }
	public @property bool isTypeString() { return payloadType() == Type.String; }
	public @property bool isTypeArray() { return payloadType() == Type.Array; }
	public @property bool isTypeObject() { return payloadType() == Type.Object; }
	public @property bool isTypeNumeric() { return payloadType() == Type.Integral || payloadType() == Type.Floating; }
	public @property bool isTypeIntegral() { return payloadType() == Type.Integral; }
	
	public var opSlice(var e1, var e2)
	{
		return this.opSlice(e1.get!ptrdiff_t, e2.get!ptrdiff_t);
	}
	
	public var opSlice(ptrdiff_t e1, ptrdiff_t e2)
	{
		if (this.payloadType() == Type.Array)
		{
			if (e1 > _payload._array.length)
				e1 = _payload._array.length;
			if (e2 > _payload._array.length)
				e2 = _payload._array.length;
			return var(_payload._array[e1..e2]);
		}
		else if (this.payloadType() == Type.String)
		{
			if (e1 > _payload._string.length)
				e1 = _payload._string.length;
			if (e2 > _payload._string.length)
				e2 = _payload._string.length;
			return var(_payload._string[e1..e2]);
		}

		throw new Exception("Unsupported type for opSlice!");
	}
	
	public @property var opDispatch(string name, string file = __FILE__, size_t line = __LINE__)() const
		if (name != "toJSON")
	{
		//pragma(msg, "Dispatching for " ~ name ~ " (" ~ file ~ ":" ~ to!string(line) ~ ")");
		auto normThis = this;
		return (cast(var*)&normThis).opIndex(name, file, line);
	}
	
	public @property var opDispatch(string name, string file = __FILE__, size_t line = __LINE__, T)(T r)
		if (name != "toJSON")
	{
		//pragma(msg, "Dispatching to assignment for " ~ name ~ " of type " ~ T.stringof ~ " (" ~ file ~ ":" ~ to!string(line) ~ ")");
		return this.opIndexAssign!T(r, name, file, line);
	}

	public var opIndexAssign(T, IT)(T pval, IT index, string file = __FILE__, size_t line = __LINE__)
		if (is(IT == string) || is(IT == size_t) || is(IT == int) || is(IT == var))
	{
		var val = pval;
		switch (this.payloadType())
		{
			case Type.Array:
				static if (is(IT == string))
				{
					if (index == "length")
						return var(_payload._array.length = cast(size_t)val);
					goto default;
				}
				else static if (is(IT == var))
				{
					if (index.payloadType() == Type.String && cast(string)index == "length")
						return var(_payload._array.length = cast(size_t)val);
					else if (index.payloadType() == Type.Integral)
					{
						if (_payload._array.length <= cast(size_t)index)
							_payload._array.length = (cast(size_t)index + 1);
						return var(_payload._array[cast(size_t)index] = val);
					}
					goto default;
				}
				else
				{
					if (_payload._array.length <= cast(size_t)index)
						_payload._array.length = (cast(size_t)index + 1);
					return var(_payload._array[index] = val);
				}
			case Type.Object:
				static if (is(IT == string))
					return var(_payload._object[index] = val);
				else static if (is(IT == var))
				{
					if (index.payloadType() == Type.String)
						return var(_payload._object[index.get!string] = val);
					goto default;
				}
				else
					goto default;
			default:
				throw new Exception("Unsupported operation on " ~ toJSON(this) ~ " assigning " ~ toJSON(pval) ~ " to index " ~ toJSON(index) ~ " for opIndexAssign!", file, line);
		}
	}

	public size_t opDollar(string file = __FILE__, size_t line = __LINE__)
	{
		return cast(size_t)this.opIndex("length", file, line);
	}

	public var opIndex(T)(T index, string file = __FILE__, size_t line = __LINE__)
		if (is(T == string) || is(T == size_t) || is(T == int))
	{
		switch (this.payloadType())
		{
			case Type.String:
				static if (is(T == string))
				{
					if (index == "length")
						return var(_payload._string.length);
					else
						goto default;
				}
				else
					return var("" ~ _payload._string[index]);
			case Type.Array:
				static if (is(T == string))
				{
					if (index == "length")
						return var(_payload._array.length);
					else
						goto default;
				}
				else
				{
					if (_payload._array.length <= cast(size_t)index)
						throw new Exception("Array index out of bounds!", file, line);
					return var(_payload._array[index]);
				}
			case Type.Object:
				static if (is(T == string))
				{
					if (auto v = index in _payload._object)
						return *v;
					throw new Exception("Attempted to retrieve the property " ~ index ~ " which doesn't exist!", file, line);
				}
				else
					goto default;
			default:
				throw new Exception("Unsupported operation for opIndex!", file, line);
		}
	}
	
	@property static var emptyObject()
	{
		var v;
		v._type = Type.Object;
		return v;
	}
	
	@property static var emptyArray()
	{
		var v;
		v._type = Type.Array;
		return v;
	}
}

class DynamicTypeException : Exception 
{
	this(var v, var.Type required, string file = __FILE__, size_t line = __LINE__)
	{
		import std.string;
		if (v.payloadType() == required)
			super(format("Tried to use null as a %s", required), file, line);
		else
			super(format("Tried to use %s as a %s", v.payloadType(), required), file, line);
	}
}

template makeAscii()
{
	string helper()
	{
		string s;
		foreach(i; 0..128)
			s ~= cast(char) i;
		return s;
	}
	
	enum makeAscii = helper();
}