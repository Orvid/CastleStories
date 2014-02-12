module CastleStory.CastleServer;

import arsd.jsvar;

import CastleStory.Analytics;
import CastleStory.Entity;
import CastleStory.Messages;
import CastleStory.Observer;
import CastleStory.Player;

import std.conv;
import std.datetime;
import std.event;
import std.random;
import std.serialization : serializable;
import std.serialization.json;

import vibe.core.core;
import vibe.core.log;

import CastleStory.stubs;

final class CastleServer
{
private:
	uint id;
	uint mMaxPlayers;
	uint mMaxObservers;
	Analytics analytics;
	uint _counter = 0;
	uint _uniqueness;
	DateTime startTime;
	uint mPlayerCount = 0;
	uint mObserverCount = 0;
	Player[size_t] mPlayers;
	Observer[size_t] observers;
	Entity[size_t] entities;
	BlockOperation[] blocks;

public:
	struct BlockOperation
	{
		size_t id;
		MessageType action;
		Message message;

		this(size_t id, MessageType action, Message message)
		{
			this.id = id;
			this.action = action;
			this.message = message;
		}

		string toString()
		{
			import std.serialization.json : toJSON;

			return `{"id":` ~ to!string(id) ~ `,"action":"` ~ to!string(action) ~ `","message":` ~ toJSON(message.serialize()) ~ `}`;
		}
	}

	@property size_t maxPlayers() inout { return mMaxPlayers; }
	@property size_t maxObservers() inout { return mMaxObservers; }
	@property size_t observerCount() inout { return mObserverCount; }
	@property size_t playerCount() inout { return mPlayerCount; }
	@property auto players() { return mPlayers; }

	Event!(void delegate(Player player)) PlayerConnect;
	Event!(void delegate(Observer observer)) ObserverConnect;
	Event!(void delegate(Player player)) PlayerEnter;
	Event!(void delegate(Observer observer)) ObserverEnter;

	this(uint id, uint maxPlayers, uint maxObservers, Analytics analytics)
	{
		this.id = id;
		this.mMaxPlayers = maxPlayers;
		this.mMaxObservers = maxObservers;
		this.analytics = analytics;

		this._uniqueness = uniform(0, 99);
		this.startTime = cast(DateTime)Clock.currTime;

		PlayerConnect ~= (player) {
			logDebug("CastleServer.PlayerConnect called with player %s", player);
		};

		ObserverConnect ~= (observer) {
			logDebug("CastleServer.ObserverConnect called with observer %s", observer);
		};

		PlayerEnter ~= (player) {
			logInfo("%s has joined %s using unique id %s", player.name, id, player.network_id);

			if (!player.hasEnteredGame)
				mPlayerCount++;

			player.Move ~= (entity, operationTime, index, validated, cancellation_level) {
				logDebug("%s %s id %s is moving to (%s)", player.name, entity.toString(), entity.network_id, index);
			};
			player.PlanMove ~= (entity, operationTime, index, validated, cancellation_level) {
				logDebug("%s %s id %s is planning to moving to (%s)", player.name, entity.toString(), entity.network_id, index);
			};

			player.Broadcast ~= (message, ignoreSelf) {
				player.socket.endpoint.sendJSON(message.serialize(), player.socket);
				if (!ignoreSelf)
					player.socket.sendJSON(message.serialize());
			};

			// Broadcast number of players in game.
			player.Broadcast(new Messages.Population(playerCount, maxPlayers), false);
			pushRelevantEntityListTo(player);

			// Start game if enough players
			if (playerCount == maxPlayers)
			{
				logInfo("We've reached the maximum number of players in game: %s", maxPlayers);
				setTimer(5.seconds, () {
					logInfo("Sending START");
					player.Broadcast(new Messages.Start(), false);
				});
			}

			player.Exit ~= () {
				logInfo("%s has left the game", player.name);
				removePlayer(player);
				mPlayerCount--;

				player.Analytics("messages", varObject(
					"from", player.name,
					"connections", playerCount,
				));
			};

			player.Analytics ~= (signal, data) {
				this.analytics.emit(signal, data);
			};
		};

		ObserverEnter ~= (observer) {
			logInfo("%s has joined %s using unique id %s as an OBSERVER", observer.name, id, observer.network_id);

			if (!observer.hasEnteredGame)
				mObserverCount++;

			observer.Broadcast ~= (message, ignoreSelf) {
				observer.socket.endpoint.sendJSON(message.serialize());
			};

			pushToPlayer(observer, new Messages.Population(observerCount, maxObservers));
			pushRelevantEntityListTo(observer);

			observer.Exit ~= () {
				logInfo("%s has left the game as an OBSERVER", observer.name);

				removeObserver(observer);
				mObserverCount--;

				observer.Analytics("messages", varObject(
					"observers", observers.length,
				));
			};
		};
	}

	void run(string mapFilePath)
	{
		logInfo("%s created (capacity: %s players, %s observers)", id, maxPlayers, maxObservers);
	}

	void updatePopulation(size_t totalPlayers = size_t.max)
	{
		//this.pushBroadcast(new Messages.Population(this.playerCount, totalPlayers ? totalPlayers : this.playerCount));
		logDebug("CastleServer.updatePopulation() totalPlayers: %s", totalPlayers == size_t.max ? playerCount : totalPlayers);
	}

	void addEntity(Entity entity)
	{
		// TODO: If it's never possible to get here
		//       with this entity already set, then
		//       make it produce an error if it occurs.
		entities[entity.network_id] = entity;

		foreach (id, player; players)
		{
			if (player.network_id != entity.belongs_to)
				pushToPlayer(player, new Messages.Spawn(entity));
		}
	}

	void updateEntity(Entity entity, DateTime operationTime, var changes)
	{
		auto obj = fromJSON!var(cast(string)changes);
		// TODO: This is slightly different from the JS code, which output
		//       the type here.
		logDebug("updateEntity %s with %s", entity, changes);

		// TODO: The original code checks to ensure that obj was
		//       valid, should that still be done?
		entity.extend(obj);

		foreach (player; players)
		{
			if (player.network_id != entity.belongs_to)
				pushToPlayer(player, new Messages.Update(entity, operationTime, changes));
		}
	}

	void addPlayer(Player player)
	{
		// We want players as Joueur entities
		addEntity(player);
		// TODO: Same question as entity addition.
		mPlayers[player.network_id] = player;
	}

	void removeEntity(Entity entity)
	{
		if (entity.network_id in entities)
			entities.remove(entity.network_id);

		entity.destroy();
		logDebug("Removed %s: %s", entity.toString(), entity.network_id);
	}

	void removePlayerEntities(Player player)
	{
		auto ents = entities.values.where!(e => e.belongs_to == player.network_id).toArray();
		foreach (e; ents)
			removeEntity(e);
		pushDespawnToPlayers(player, ents);

		// TODO: Why are we resetting the blocks when only 1 player was removed?
		//blocks = null;
	}

	void removePlayer(Player player)
	{
		// some entities belong to players, we must despawn and remove them
		removePlayerEntities(player);
		removeEntity(player);
		mPlayers.remove(player.network_id);
	}

	Entity getEntityByID(size_t id)
	{
		// TODO: Need to update everywhere using this
		//       to fail silently if this returns null.
		if (auto e = id in entities)
			return *e;
		logError("Unknown entity: %s", id);
		return null;
	}

	size_t getPlayerIndex()
	{
		for (size_t i = 0; i < playerCount; i++)
		{
			if (!players.values.where!(p => p.index == i).firstOrDefault())
				return i;
		}
		return playerCount;
	}

	alias _createID = getID;
	size_t getID()
	{
		return to!size_t("5" ~ _uniqueness.to!string() ~ (_counter++).to!string());
	}

	void pushToPlayer(scope Observer target, Message msg)
	{
		if (target)
			target.send(msg.serialize());
		else
			logError("pushToPlayer: Player was null");
	}

	void pushRelevantEntityListTo(Observer target) 
	{
		auto ids = entities.keys.where!(e => e != target.network_id).toArray();
		logInfo("Pushing a list of %s entities to player: %s", ids.length, target.name);
		if (ids.length > 0)
			pushToPlayer(target, new Messages.List(ids));
	}

	void pushRelevantEntityTo(Observer target)
	{
		auto ents = entities.values.where!(e => e.belongs_to != target.network_id).toArray();
		logDebug("Pushing %s entities to player: %s", ents.length, target.name);
		if (ents.length > 0)
		{
			foreach (e; ents)
			{
				auto msg = new Messages.Spawn(e);
				logDebug("pushRelevantEntityTo: msg: %s", msg.serialize());
				pushToPlayer(target, msg);
			}
		}
	}

	void pushSpawnsToPlayer(Observer target, size_t[] ids)
	{
		foreach (id; ids)
		{
			auto ent = getEntityByID(id);
			auto msg = new Messages.Spawn(ent);

			// TODO: There was some fun stuff in here, figure out what it was for.

			pushToPlayer(target, msg);
		}

		logDebug("Pushed %s new spawns to player %s", ids.length, target.name);
	}

	void pushDespawnToPlayers(Player from, Entity[] entities)
	{
		foreach (e; entities)
			from.Broadcast(new Messages.Despawn(e), true);
		logDebug("Pushed %s despawns from player %s", entities.length, from.name);
	}

	bool isValidPosition(size_t index)
	{
		return true;
	}

	Duration getTime()
	{
		return cast(DateTime)Clock.currTime - this.startTime;
	}

	void blockOp(size_t id, MessageType action, Message message)
	{
		blocks ~= BlockOperation(id, action, message);
	}

	void pushRelevantBlockListTo(Observer target)
	{
		import std.serialization.json;

		// TODO: The original code had this filter commented out.
		auto blcks = blocks.where!(b => b.id != target.network_id).toArray();
		logInfo("Pushed %s bloc/debloc to player %s", blcks.length, target.name);
		foreach (b; blcks)
		{
			logDebug("Sending block: %s", b.toJSON());
			pushToPlayer(target, b.message);
		}
	}

	void addObserver(Observer observer)
	{
		// TODO: Implement me!
	}

	void removeObserver(Observer observer) 
	{
		// TODO: Implement me!
	}

	size_t getObserverIndex()
	{
		for (size_t i = 0; i < observerCount; i++)
		{
			if (!observers.values.where!(o => o.index == i).firstOrDefault())
				return i;
		}
		return observerCount;
	}
}

