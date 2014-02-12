module CastleStory.Entity;

import arsd.jsvar;

import CastleStory.Messages;

@scriptable 
class Entity
{
protected:
	var inner = varObject();

public:
	@property size_t network_id() const { return cast(size_t)inner.network_id; }
	@property size_t belongs_to() const { return cast(size_t)inner.belongs_to; }
	@property uint type() const { return cast(uint)inner.type; }
	@property uint kind() const { return cast(uint)inner.kind; }
	@property int x() const { return cast(int)inner.x; }
	@property int y() const { return cast(int)inner.y; }

	this(size_t network_id, size_t belongs_to)
	{
		this.inner.network_id = network_id;
		this.inner.belongs_to = belongs_to;
	}

	var getState()
	{
		return varArray(network_id); 
	}

	override string toString()
	{
		return inner.toString();
	}

	final void extend(var v)
	in
	{
		assert(v.payloadType() == var.Type.Object);
	}
	body
	{
		foreach (k, v; v)
		{
			inner[k] = v;
		}
	}
}