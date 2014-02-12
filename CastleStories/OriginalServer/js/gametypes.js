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

Types = {
    Messages: {
        HELLO: 0,
        WELCOME: 1,
        SPAWN: 2,
        DESPAWN: 3,
        MOVE: 4,
        PLANMOVE: 5,
        CLEAR: 6,
        MODE: 7,
        HIT: 8,
        CHOP: 9,
        UPDATE: 10,
        CHAT: 11,
        TIME: 12,
        EQUIP: 13,
        UNEQUIP: 14,
        ACTION: 15,
        DAMAGE: 16,
        POPULATION: 17,
        KILL: 18,
        LIST: 19,
        WHO: 20,
        BLOC: 21,
        DEBLOC: 22,
        HP: 23,
        ADD: 24,
        AIM: 25,
        CHECK: 26,
        PATH: 27,
        START: 28,
    },
    
    Entities: {
        PLAYER: 1,
        // Characters
        BRIXTRON: 2,
		// Generics
		GENERIC: 99,
    },
};

var messages = {
    hello: [Types.Messages.HELLO, "HELLO"],
    welcome: [Types.Messages.WELCOME, "WELCOME"],
    spawn: [Types.Messages.SPAWN, "SPAWN"],
    despawn: [Types.Messages.DESPAWN, "DESPAWN"],
    move: [Types.Messages.MOVE, "MOVE"],
    planmove: [Types.Messages.PLANMOVE, "PLANMOVE"],
    chop: [Types.Messages.CHOP, "CHOP"],	
    time: [Types.Messages.TIME, "TIME"],
    action: [Types.Messages.ACTION, "ACTION"],  
	bloc: [Types.Messages.BLOC, "BLOC"],  
	debloc: [Types.Messages.DEBLOC, "DEBLOC"],    
	equip: [Types.Messages.EQUIP, "EQUIP"],   
	unequip: [Types.Messages.UNEQUIP, "UNEQUIP"],   
    update: [Types.Messages.UPDATE, "UPDATE"],  
    add: [Types.Messages.ADD, "ADD"],  
    hit: [Types.Messages.HIT, "HIT"],  
    aim: [Types.Messages.AIM, "AIM"], 
    path: [Types.Messages.PATH, "PATH"],
    damage: [Types.Messages.DAMAGE, "DAMAGE"], 
        		        
    getType: function(message) {
        return messages[Types.getMessageAsString(message)][1];
    }
};

Types.getMessageAsString = function(message) {
    for(var m in messages) {
        if(messages[m][0] === message) {
            return m;
        }
    }
};
    
var kinds = {
    player: [Types.Entities.PLAYER, "player"],
    brixtron: [Types.Entities.BRIXTRON, "brixtron"],
	generic: [Types.Entities.GENERIC, "generic"],
    
    getType: function(kind) {
        return kinds[Types.getKindAsString(kind)][1];
    }
};

Types.getKindAsString = function(kind) {
    for(var k in kinds) {
        if(kinds[k][0] === kind) {
            return k;
        }
    }
};

if(!(typeof exports === 'undefined')) {
    module.exports = Types;
}