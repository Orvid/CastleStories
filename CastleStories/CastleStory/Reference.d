module CastleStory.Reference;

import arsd.jsvar;

import CastleStory.Entity;

@scriptable
final class Reference : Entity
{
	this(var json)
	{
		extend(json);
		super(0, 0);
	}

	override var getState()
	{
		return this.inner;
	}
}