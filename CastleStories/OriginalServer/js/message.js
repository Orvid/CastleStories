/*
This is part of Castle Story Multiplayer Server
Copyright (C) 2013  SauropodStudio, Inc

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

var cls = require("./lib/class"),
    _ = require("underscore"),
    Utils = require("./utils"),
    Types = require("./gametypes");

var Messages = {};
module.exports = Messages;

var Message = cls.Class.extend({
});

Messages.Spawn = Message.extend({
    init: function(entity) {
        this.entity = entity;
    },
    serialize: function() {
        var spawn = [Types.Messages.SPAWN];
		spawn.push(this.entity.getState());
        return spawn;
    }
});

Messages.Despawn = Message.extend({
    init: function(entity) {
        this.entity = entity;
    },
    serialize: function() {
        return [Types.Messages.DESPAWN, this.entity.network_id];
    }
});

Messages.Move = Message.extend({
    init: function(entity,operationTime) {
        this.entity = entity;
        this.operationTime = operationTime;
    },
    serialize: function() {
        return [Types.Messages.MOVE,
                this.entity.network_id,
                this.entity.x,
                this.entity.y];
    }
});

Messages.PlanMove = Message.extend({
    init: function(entity, operationTime, index, validated, cancellation_level) {
        this.entity = entity;
        this.operationTime = operationTime;
        this.index = index;
        this.validated = validated;
        this.cancellation_level = cancellation_level;
    },
    serialize: function() {
        return [Types.Messages.PLANMOVE,
                this.operationTime,
                this.entity.network_id,
                this.index,
                this.validated,
                this.cancellation_level];
    }
});

Messages.Clear = Message.extend({
    init: function(entity, operationTime) {
        this.entity = entity;
        this.operationTime = operationTime;
    },
    serialize: function() {
        return [Types.Messages.CLEAR,
                this.entity.network_id];
    }
});

Messages.Mode = Message.extend({
    init: function(entity, operationTime, mode) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.mode = mode;
    },
    serialize: function() {
        return [Types.Messages.MODE,
                this.entity.network_id,
				this.mode];
    }
});

Messages.Chop = Message.extend({
    init: function(entity, operationTime, index) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.index = index;
    },
    serialize: function() {
        return [Types.Messages.CHOP,
                this.entity.network_id,
				this.index];
    }
});

Messages.Attack = Message.extend({
    init: function(attackerId, targetId) {
        this.attackerId = attackerId;
        this.targetId = targetId;
    },
    serialize: function() {
        return [Types.Messages.ATTACK,
                this.attackerId,
                this.targetId];
    }
});

Messages.Update = Message.extend({
    init: function(entity, operationTime, changes) {
        this.entity = entity;
        this.operationTime = operationTime;
        this.changes = changes;
    },
    serialize: function() {
        return [Types.Messages.UPDATE,
                this.entity.network_id,
                this.changes];
    }
});

Messages.Start = Message.extend({
    init: function() {
    },
    serialize: function() {
        return [Types.Messages.START];
    }
});

Messages.Equip = Message.extend({
    init: function(entity, operationTime, mode, type, count) {
        this.entity = entity;
        this.operationTime = operationTime;
        this.mode = mode;
        this.type = type;
		this.count = count;
    },
    serialize: function() {
        return [Types.Messages.EQUIP,
                this.entity.network_id,
                this.mode,
                this.type,
				this.count];
    }
});

Messages.Unequip = Message.extend({
    init: function(entity, operationTime, item, count) {
        this.entity = entity;
        this.operationTime = operationTime;
        this.item = item;
		this.count = count;
    },
    serialize: function() {
        return [Types.Messages.UNEQUIP,
                this.entity.network_id,
                this.item,
				this.count];
    }
});

Messages.Drop = Message.extend({
    init: function(entity) {
        this.entity = entity;
    },
    serialize: function() {
        return [Types.Messages.DROP,
                this.entity.network_id];
    }
});

Messages.Chat = Message.extend({
    init: function(player, message) {
        this.playerId = player.id;
        this.message = message;
    },
    serialize: function() {
        return [Types.Messages.CHAT,
                this.playerId,
                this.message];
    }
});

Messages.Action = Message.extend({
    init: function(entity, operationTime, instructions) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.instructions = instructions;
    },
    serialize: function() {
        return [Types.Messages.ACTION,
                this.entity.network_id,
				this.instructions];
    }
});

Messages.Damage = Message.extend({
    init: function(entity, points) {
        this.entity = entity;
        this.points = points;
    },
    serialize: function() {
        return [Types.Messages.DAMAGE,
                this.entity.id,
                this.points];
    }
});

Messages.Population = Message.extend({
    init: function(game, total) {
        this.game = game;
        this.total = total;
    },
    serialize: function() {
        return [Types.Messages.POPULATION,
                this.game,
                this.total];
    }
});

Messages.Kill = Message.extend({
    init: function(mob) {
        this.mob = mob;
    },
    serialize: function() {
        return [Types.Messages.KILL,
                this.mob.kind];
    }
});

Messages.List = Message.extend({
    init: function(ids) {
        this.ids = ids;
    },
    serialize: function() {
        var list = this.ids;
        
        list.unshift(Types.Messages.LIST);
        return list;
    }
});

Messages.Bloc = Message.extend({
    init: function(index,paire,type,variante,niveaux) {
		this.index = index;
		this.paire = paire;
		this.type = type;
		this.variante = variante;
		this.niveaux = niveaux;
    },
    serialize: function() {
        return [Types.Messages.BLOC,
                this.index,
				this.paire,
				this.type,
				this.variante,
				this.niveaux];
    }
});

Messages.DeBloc = Message.extend({
    init: function(pos,real,gravity) {
        this.pos = pos;
		this.real = real;
		this.gravity = gravity;
    },
    serialize: function() {
        return [Types.Messages.DEBLOC,
                this.pos,
				this.real,
				this.gravity];
    }
});

Messages.Add = Message.extend({
    init: function(entity, operationTime, item, recipient) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.item = item;
        this.recipient = recipient
    },
    serialize: function() {
        return [Types.Messages.ADD,
                this.entity.network_id,
				this.item,
                this.recipient.network_id];
    }
});

Messages.Hit = Message.extend({
    init: function(entity, operationTime) {
        this.entity = entity;
        this.operationTime = operationTime;
    },
    serialize: function() {
        return [Types.Messages.HIT,
                this.entity.network_id];
    }
});

Messages.Aim = Message.extend({
    init: function(entity, operationTime, target) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.target = target;
    },
    serialize: function() {
        return [Types.Messages.AIM,
                this.entity.network_id,
				this.target];
    }
});

Messages.Path = Message.extend({
    init: function(entity, operationTime, action, data) {
        this.entity = entity;
        this.operationTime = operationTime;
		this.action = action;
        this.data = data;
    },
    serialize: function() {
        return [Types.Messages.PATH,
                this.entity.network_id,
				this.action,
                this.data];
    }
});

Messages.Damage = Message.extend({
    init: function(entity, operationTime, mode, from, data) {
        this.entity = entity;
        this.operationTime = operationTime;
        this.mode = mode;
		this.from = from;
        this.data = data;
    },
    serialize: function() {
        return [Types.Messages.DAMAGE,
                this.entity.network_id,
				this.from,
                this.data];
    }
});