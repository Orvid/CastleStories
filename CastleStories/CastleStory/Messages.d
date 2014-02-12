module CastleStory.Messages;

import arsd.jsvar;

import CastleStory.Entity;
import CastleStory.Observer;

import std.datetime;


enum EntityKind
{
	Player = 1,
	Brixtron = 2,
	Generic = 99,
}

enum MessageType
{
	Hello = 0,
	Welcome = 1,
	Spawn = 2,
	Despawn = 3,
	Move = 4,
	PlanMove = 5,
	Clear = 6,
	Mode = 7,
	Hit = 8,
	Chop = 9,
	Update = 10,
	Chat = 11,
	Time = 12,
	Equip = 13,
	Unequip = 14,
	Action = 15,
	Damage = 16,
	Population = 17,
	Kill = 18,
	List = 19,
	Who = 20,
	Bloc = 21,
	Debloc = 22,
	HP = 23,
	Add = 24,
	Aim = 25,
	Check = 26,
	Path = 27,
	Start = 28,

	// TODO: Make sure this matches the official version.
	Drop = 29,
	Attack = 30,
}

abstract class Message
{
	abstract var serialize();
}

struct Messages
{
	// TODO: Implement me!
	final class Hello : Message
	{
	private:
		
	public:
		this()
		{
			
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Hello
			);
		}
	}

	final class Welcome : Message
	{
	private:
		Observer player;
		
	public:
		this(Observer player)
		{
			this.player = player;
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Welcome,
				player.index,
				player.network_id,
				player.name
			);
		}
	}

	final class Spawn : Message
	{
	private:
		Entity entity;

	public:
		this(Entity entity)
		{
			this.entity = entity;
		}

		override var serialize()
		{
			auto arr = varArray(MessageType.Spawn);
			arr ~= entity.getState();
			return arr;
		}
	}

	final class Despawn : Message
	{
	private:
		Entity entity;

	public:
		this(Entity entity)
		{
			this.entity = entity;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Despawn,
				entity.network_id
			);
		}
	}

	final class Move : Message
	{
	private:
		Entity entity;
		DateTime operationTime;

	public:
		this(Entity entity, DateTime operationTime)
		{
			this.entity = entity;
			this.operationTime = operationTime;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Move,
				entity.network_id,
				entity.x,
				entity.y
			);
		}
	}

	final class PlanMove : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		size_t index;
		bool validated;
		uint cancellation_level;

		// TODO: I don't know if 'cancellation_level' is actually supposed to be a uint.
	public:
		this(Entity entity, DateTime operationTime, size_t index, bool validated, uint cancellation_level)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.index = index;
			this.validated = validated;
			this.cancellation_level = cancellation_level;
		}

		override var serialize()
		{
			return varArray(
				MessageType.PlanMove,
				operationTime.toISOString(),
				entity.network_id,
				index,
				validated,
				cancellation_level
			);
		}
	}

	final class Clear : Message
	{
	private:
		Entity entity;
		DateTime operationTime;

	public:
		this(Entity entity, DateTime operationTime)
		{
			this.entity = entity;
			this.operationTime = operationTime;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Clear,
				entity.network_id
			);
		}
	}

	final class Mode : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var mode;

		// TODO: Figure out the concrete type for 'mode'
	public:
		this(Entity entity, DateTime operationTime, var mode)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.mode = mode;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Mode,
				entity.network_id,
				mode
			);
		}
	}
	
	final class Hit : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		
	public:
		this(Entity entity, DateTime operationTime)
		{
			this.entity = entity;
			this.operationTime = operationTime;
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Hit,
				entity.network_id
			);
		}
	}

	final class Chop : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		size_t index;

	public:
		this(Entity entity, DateTime operationTime, size_t index)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.index = index;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Chop,
				entity.network_id,
				index
			);
		}
	}

	final class Update : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var changes;

	public:
		this(Entity entity, DateTime operationTime, var changes)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.changes = changes;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Update,
				entity.network_id,
				changes
			);
		}
	}
	
	final class Chat : Message
	{
	private:
		Observer source;
		string message;
		
	public:
		this(Observer source, string message)
		{
			this.source = source;
			this.message = message;
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Chat,
				source.network_id,
				message
			);
		}
	}

	// TODO: Implement me!
	final class Time : Message
	{
	private:
		
	public:
		this()
		{
			
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Time
			);
		}
	}

	final class Equip : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var mode;
		var type;
		size_t count;

		// TODO: Figure out the concrete types for 'mode' and 'type'
		// TODO: Make all locations respect the fact that 'count' is in fact 'count_or_id'
	public:
		this(Entity entity, DateTime operationTime, var mode, var type, size_t count_or_id)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.mode = mode;
			this.type = type;
			this.count = count_or_id;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Equip,
				entity.network_id,
				mode,
				type,
				count
			);
		}
	}

	final class Unequip : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var item;
		size_t count;

		// TODO: Figure out the concrete type of 'item'
	public:
		this(Entity entity, DateTime operationTime, var item, size_t count)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.item = item;
			this.count = count;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Unequip,
				entity.network_id,
				item,
				count
			);
		}
	}

	final class Action : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var instructions;

		// TODO: Figure out the type of the 'instructions' param.
	public:
		this(Entity entity, DateTime operationTime, var instructions)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.instructions = instructions;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Action,
				entity.network_id,
				instructions
			);
		}
	}

	final class Damage : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var mode;
		var from;
		var data;

	public:
		this(Entity entity, DateTime operationTime, var mode, var from, var data)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.mode = mode;
			this.from = from;
			this.data = data;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Damage,
				entity.network_id,
				from,
				data
			);
		}
	}

	final class Population : Message
	{
	private:
		size_t game;
		// TODO: This is currently passed as the max number of players,
		//       which doesn't reflect the name of this variable.
		size_t total;

	public:
		this(size_t game, size_t total)
		{
			this.game = game;
			this.total = total;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Population,
				game,
				total
			);
		}
	}

	final class Kill : Message
	{
	private:
		Entity mob;

	public:
		this(Entity mob)
		{
			this.mob = mob;
		}

		override var serialize()
		{
			// TODO: Shouldn't there be a bit more info here?
			return varArray(
				MessageType.Kill,
				mob.kind
			);
		}
	}

	final class List : Message
	{
	private:
		size_t[] ids;

	public:
		this(size_t[] ids)
		{
			this.ids = ids;
		}

		override var serialize()
		{
			var arr = varArray(MessageType.List);
			// TODO: No idea if this is correct.
			arr ~= cast(var)ids;
			return arr;
		}
	}

	// TODO: Implement me!
	final class Who : Message
	{
	private:
		
	public:
		this()
		{
			
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Who
			);
		}
	}

	final class Bloc : Message
	{
	private:
		size_t index;
		var paire;
		var type;
		var variante;
		var niveaux;

		// TODO: Figure out the concrete types for these params.
	public:
		this(size_t index, var paire, var type, var variante, var niveaux)
		{
			this.index = index;
			this.paire = paire;
			this.type = type;
			this.variante = variante;
			this.niveaux = niveaux;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Bloc,
				index,
				paire,
				type,
				variante,
				niveaux
			);
		}
	}

	final class Debloc : Message
	{
	private:
		var pos;
		var real_;
		var gravity;

		// TODO: I have no idea what type any of these are supposed to be.
	public:
		this(var pos, var real_, var gravity)
		{
			this.pos = pos;
			this.real_ = real_;
			this.gravity = gravity;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Debloc,
				pos,
				real_,
				gravity
			);
		}
	}
	
	// TODO: Implement me!
	final class HP : Message
	{
	private:
		
	public:
		this()
		{
			
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.HP
			);
		}
	}

	final class Add : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var item;
		Entity recipient;

		// TODO: Figure out a concrete type for 'item'
	public:
		this(Entity entity, DateTime operationTime, var item, Entity recipient)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.item = item;
			this.recipient = recipient;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Add,
				entity.network_id,
				item,
				recipient.network_id
			);
		}
	}

	final class Aim : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var target;

		// TODO: What type is 'target' actually supposed to be?
	public:
		this(Entity entity, DateTime operationTime, var target)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.target = target;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Aim,
				entity.network_id,
				target
			);
		}
	}
	
	// TODO: Implement me!
	final class Check : Message
	{
	private:
		
	public:
		this()
		{
			
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Check
			);
		}
	}

	final class Path : Message
	{
	private:
		Entity entity;
		DateTime operationTime;
		var path_action;
		var data;

	public:
		this(Entity entity, DateTime operationTime, var path_action, var data)
		{
			this.entity = entity;
			this.operationTime = operationTime;
			this.path_action = path_action;
			this.data = data;
		}

		override var serialize()
		{
			return varArray(
				MessageType.Path,
				entity.network_id,
				path_action,
				data
			);
		}
	}
	
	final class Start : Message
	{
		this()
		{
		}
		
		override var serialize()
		{
			return varArray(MessageType.Start);
		}
	}
	
	final class Drop : Message
	{
	private:
		Entity entity;
		
	public:
		this(Entity entity)
		{
			this.entity = entity;
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Drop,
				entity.network_id
			);
		}
	}
	
	final class Attack : Message
	{
	private:
		Entity attacker;
		Entity target;
		
	public:
		this(Entity attacker, Entity target)
		{
			this.attacker = attacker;
			this.target = target;
		}
		
		override var serialize()
		{
			return varArray(
				MessageType.Attack,
				attacker.network_id,
				target.network_id
			);
		}
	}
}