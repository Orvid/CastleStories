module CastleStory.Player;

import arsd.jsvar;

import CastleStory.ArbreCoupe;
import CastleStory.Brixtron;
import CastleStory.CastleServer;
import CastleStory.Config;
import CastleStory.Entity;
import CastleStory.Generic;
import CastleStory.Observer;
import CastleStory.Messages;
import CastleStory.Reference;

import socket.io;

import std.conv;
import std.datetime;
import std.event;
import std.serialization.json;
import std.string;

import vibe.core.core;
import vibe.core.log;

import CastleStory.stubs;


@scriptable
final class Player : Observer
{
private:
	static __gshared immutable Entity function(size_t network_id, size_t belongs_to, var value)[string] entityFactories;
	
	shared static this()
	{
		static Entity stub(T)(size_t n, size_t b, var v) { return new T(n, b, v); }
		entityFactories = 
		[
			"ArbreCoupe": &stub!ArbreCoupe,
			"Brixtron": &stub!Brixtron,
		];
	}

public:
	Event!(void delegate(Entity entity, DateTime operationTime, size_t index, bool validated, uint cancellation_level)) Move;
	Event!(void delegate(Entity entity, DateTime operationTime, size_t index, bool validated, uint cancellation_level)) PlanMove;

	this(SocketConnection socket, Endpoint domain, CastleServer server)
	{
		super(socket, domain, server);
		logDebug("Player unique id: %s", network_id);

		Analytics ~= (msg, props) {

		};

		socket.message ~= (message, callbackFn) {
			try
			{
				logDebug("Player.onMessage: msg: %s", message);
				auto action = cast(MessageType)cast(uint)cast(double)message[0];
				auto reseauTime = cast(double)message[1];
				// TODO: Figure out how to convert this value to a DateTime.
				//auto operationTime = to!double(message[2]);
				DateTime operationTime = cast(DateTime)Clock.currTime;

				if (config.latency)
					sleep(msecs(config.latency));

				// TODO: Add checks to all of these to make sure there are enough values
				//       in the message param.
				switch (action)
				{
					case MessageType.Hello:
						logDebug("Player.onMessage HELLO");
						
						this.mName = cast(string)message[3];
						// index is first free slot from 0 to server.playerCount
						this.mIndex = server.getPlayerIndex();
						if (!mName || mName == "")
						{
							this.mName = "Player " ~ to!string(index);
						}
						server.addPlayer(this);
						send(new Messages.Welcome(this).serialize());
						server.PlayerEnter(this);
						this.mHasEnteredGame = true;
						break;
					// 1
					case MessageType.Spawn:
						auto valV = fromJSON!var(cast(string)message[3], (name, value) {
							if (value.payloadType == var.Type.Object)
							{
								//logDebug("Welp...");
								if ("$type" in value)
								{
									//logDebug("Delp...");
									auto newType = cast(string)split(cast(string)value["$type"], ',')[0];
									//logDebug("Aww...");
									if (auto factory = newType in entityFactories)
									{
										//logDebug("Golly gee...");
										auto newVal = (*factory)(server.getID(), network_id, value);
										logDebug("Player.onMessage SPAWN type: %s object: %s", newType, newVal);
										return cast(var)newVal;
									}
									else
									{
										//logDebug("Or else maybe %s?", server.getID());
										auto newValue = new Generic(server.getID(), network_id, value);
										logDebug("Player.onMessage SPAWN type: GENERIC object: %s", newValue);
										return cast(var)newValue;
									}
								}
								else
								{
									auto newValue = new Reference(value);
									logDebug("Player.onMessage SPAWN type: REFERENCE object: %s", newValue);
									return cast(var)newValue;
								}
							}
							//logDebug("Non-object entity: %s:%s", name, value);
							return value;
						});
						auto obj = cast(Entity)cast(Object)valV;
						server.addEntity(obj);
						auto v = cast(var)obj.network_id;
						logDebug("Player.onMessage SPAWN returning network_id: %s", obj.network_id);
						callbackFn([cast(var)obj.network_id]);
						break;
					case MessageType.Despawn:
						size_t id = cast(size_t)message[3];
						auto ent = server.getEntityByID(id);

						logDebug("Player.onMessage DESPAWN id: %s", id);
						Broadcast(new Messages.Despawn(ent), true);
						server.removeEntity(ent);
						break;
					case MessageType.Move:
						logDebug("Player.onMessage MOVE operationTime: %s Reseau.time: %s server time: %s", operationTime, reseauTime, server.getTime().total!"msecs" / 1000.0);
						auto id = cast(size_t)message[3];
						auto index = cast(size_t)message[4];
						bool validated = cast(bool)message[5];
						uint cancellation_level = cast(uint)message[6];
						auto entity = server.getEntityByID(id);
						if (server.isValidPosition(index))
						{
							// TODO: this should be sending a Move message, not PlanMove
							Broadcast(new Messages.PlanMove(entity, operationTime, index, validated, cancellation_level), true);
							Move(entity, operationTime, index, validated, cancellation_level);
						}
						// TODO: Add a log message for an invalid position.
						break;
					case MessageType.PlanMove:
						auto id = cast(size_t)message[3];
						auto index = cast(size_t)message[4];
						bool validated = cast(bool)message[5];
						uint cancellation_level = cast(uint)message[6];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage PLANMOVE id: %s index: %s validated: %s cancellation_level: %s", id, index, validated, cancellation_level);
						if (server.isValidPosition(index))
						{
							Broadcast(new Messages.PlanMove(entity, operationTime, index, validated, cancellation_level), true);
							PlanMove(entity, operationTime, index, validated, cancellation_level);
						}
						// TODO: Add a log message for an invalid position.
						break;
					case MessageType.Clear:
						auto id = cast(size_t)message[3];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage CLEAR entity: %s", id);
						Broadcast(new Messages.Clear(entity, operationTime), true);
						break;
					case MessageType.Mode:
						auto id = cast(size_t)message[3];
						auto mode = message[4];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage MODE entity: %s mode: %s", id, mode);
						Broadcast(new Messages.Mode(entity, operationTime, mode), true);
						break;
					case MessageType.Hit:
						auto id = cast(size_t)message[3];
						auto entity = server.getEntityByID(id);
						
						logDebug("Player.onMessage HIT id: %s", id);
						Broadcast(new Messages.Hit(entity, operationTime), true);
						break;
					case MessageType.Chop:
						auto id = cast(size_t)message[3];
						auto index = cast(size_t)message[4];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage CHOP id: %s index: %s", id, index);
						Broadcast(new Messages.Chop(entity, operationTime, index), true);
						break;
					case MessageType.Update:
						auto id = cast(size_t)message[3];
						auto changes = message[4];
						auto entity = server.getEntityByID(id);
						
						logDebug("Player.onMessage UPDATE id: %s entity: %s changes: %s", id, entity.getState(), changes);
						// update server entity
						server.updateEntity(entity, operationTime, changes);
						break;
					// 11
					case MessageType.Time:
						callbackFn([cast(var)reseauTime, cast(var)server.getTime().total!"seconds"]);
						break;
					case MessageType.Equip:
						auto id = cast(size_t)message[3];
						auto mode = message[4];
						auto type = message[5];
						size_t count_or_id = cast(size_t)message[6];
						auto entity = server.getEntityByID(id);
						
						logDebug("Player.onMessage EQUIP id: %s mode: %s type: %s count_or_id: %s", id, mode, type, count_or_id);
						Broadcast(new Messages.Equip(entity, operationTime, mode, type, count_or_id), true);
						break;
					case MessageType.Unequip:
						auto id = cast(size_t)message[3];
						auto item = message[4];
						auto count = cast(size_t)message[5];
						auto entity = server.getEntityByID(id);
						
						logDebug("Player.onMessage UNEQUIP id: %s item: %s count: %s", id, item, count);
						Broadcast(new Messages.Unequip(entity, operationTime, item, count), true);
						break;
					case MessageType.Action:
						auto id = cast(size_t)message[3];
						auto instructions = message[4];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage ACTION id: %s instructions: %s", id, instructions);
						Broadcast(new Messages.Action(entity, operationTime, instructions), true);
						break;
					case MessageType.Damage:
						auto id = cast(size_t)message[3];
						auto mode = message[4];
						auto from = message[5];
						auto data = message[6];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage DAMAGE id: %s mode: %s from: %s data: %s", id, mode, from, data);
						Broadcast(new Messages.Damage(entity, operationTime, mode, from, data), true);
						break;
					// 17
					// 18
					// 19
					case MessageType.Who:
						auto ids = cast(size_t[])message[3..$];

						logDebug("Player.onMessage WHO ids: %s", ids);
						server.pushSpawnsToPlayer(this, ids);
						server.pushRelevantBlockListTo(this);
						break;
					case MessageType.Bloc:
						auto index = cast(size_t)message[3];
						auto paire = message[4];
						auto type = message[5];
						auto variante = message[6];
						auto niveaux = message[7];

						logDebug("Player.onMessage BLOC index: %s paire: %s type: %s variante: %s niveaux: %s", index, paire, type, variante, niveaux);
						// Store BLOC/DEBLOC operations for updating joining players
						auto newMessage = new Messages.Bloc(index, paire, type, variante, niveaux);
						server.blockOp(network_id, action, newMessage);
						Broadcast(newMessage, true);
						break;
					case MessageType.Debloc:
						auto pos = message[3];
						auto real_ = message[4];
						auto gravity = message[5];
						
						logDebug("Player.onMessage DEBLOC pos: %s real: %s gravity: %s", pos, real_, gravity);
						// Store BLOC/DEBLOC operations for updating joining players
						auto newMessage = new Messages.Debloc(pos, real_, gravity);
						server.blockOp(network_id, action, newMessage);
						Broadcast(newMessage, true);
						break;
					// 23
					case MessageType.Add:
						auto id = cast(size_t)message[3];
						auto item = message[4];
						auto into = cast(size_t)message[5];
						auto entity = server.getEntityByID(id);
						auto recipient = server.getEntityByID(into);

						logDebug("Player.onMessage ADD id: %s item: %s into: %s", id, item, into);
						Broadcast(new Messages.Add(entity, operationTime, item, recipient), true);
						break;
					case MessageType.Aim:
						auto id = cast(size_t)message[3];
						auto target = message[4];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage AIM id: %s target: %s", id, target);
						Broadcast(new Messages.Aim(entity, operationTime, target), true);
						break;
					// 26
					case MessageType.Path:
						auto id = cast(size_t)message[3];
						auto path_action = message[4];
						auto data = message[5];
						auto entity = server.getEntityByID(id);

						logDebug("Player.onMessage PATH id: %s path_action: %s data: %s", id, path_action, data);
						Broadcast(new Messages.Path(entity, operationTime, path_action, data), true);
						break;
					default:
						logError("Unhandled message type %s", action);
						//UnhandledMessage(message, callbackFn);
						break;
				}

				mIP = socket.handshake.peer;
				Analytics("messages", varObject(
					"from", name,
					"connections", server.players.length,
					"msg", message,
					//"players", server.players,
					"action", action.to!string(),
					"timestamp", format("%.3s", server.getTime().total!"seconds"),
				));
			}
			catch (Exception e)
			{
				logError("player.onMessage error: %s", e);
			}
		};

		socket.disconnect ~= () {
			logDebug("Player.socket.onDisconnect");
			Exit();
		};
	}

	override var getState()
	{
		return varObject(
			"network_id", network_id,
			"index", index,
			"nom", name,
			"$type", "Joueur, Assembly-UnityScript"
		);
	}
}
