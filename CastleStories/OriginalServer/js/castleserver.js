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

var cls = require("./lib/class")
    , _ = require("underscore")
    , Messages = require('./message')
    , sleep = require('sleep')
    , Utils = require("./utils")
    
module.exports = Game = cls.Class.extend({
    init: function(id, maxPlayers, maxObservers, websocketServer, analytics) {
        var self = this;

        this.id = id;
        this.maxPlayers = maxPlayers;
        this.maxObservers = maxObservers;
        this.server = websocketServer;
        this.analytics = analytics;
        this._counter = 0;
        this._uniqueness = Utils.random(99);
		
		this.startTime = new Date().getTime();
    
        this.playerCount = 0;
        this.observerCount = 0;
        
        this.entities = {};
        this.players = {};
        this.observers = {};
        this.blocks = [];
        
        this.onPlayerConnect(function(player) {
            log.debug('Game.onPlayerConnect called for player '+player)
        });

        this.onObserverConnect(function(observer) {
            log.debug('Game.onObserverConnect called for observer '+observer)
        });
                
        this.onPlayerEnter(function(player) {
            log.info(player.name + " has joined "+ self.id + " using unique id " + player.network_id);
            
            if(!player.hasEnteredGame) {
                self.incrementPlayerCount();
            }

            var move_callback = function(entity, index, validated, cancellation_level) {
                log.debug(player.name + " " + entity.type + " id " + entity.network_id + " is moving to (" + index + ").");
            };

            player.onMove(move_callback);
            player.onPlanMove(move_callback);
            
            player.onBroadcast(function(message, ignoreSelf) {
                this.socket.broadcast.json.send(message.serialize());
                if (ignoreSelf == false){
                    this.socket.json.send(message.serialize());
                }
            });
                        
            // Number of players in this game
            player.broadcast(new Messages.Population(self.playerCount,self.maxPlayers), false);
            self.pushRelevantEntityListTo(player); 
            
            // check is we should start the game and lock the game
            if (self.playerCount == self.maxPlayers){
                log.info('We reached maximum players in game: ' + self.maxPlayers);
                setTimeout(function() { 
                    log.info('Sending START.');
                    player.broadcast(new Messages.Start(), false); 
                }, 5000);
            }   

            player.onExit(function() {
                log.info(player.name + " has left the game.");
                self.removePlayer(player);
                self.decrementPlayerCount();
                
                if(self.removed_callback) {
                    self.removed_callback();
                }
                this.analytics_callback('messages', { 
                     'from' : player.name,
                     'connections' : playerCount, 
                });
            });
            
            if(self.added_callback) {
                self.added_callback();
            }
            
            if (self.analytics) {
                var analytics_callback = function(signal, data) {
                    self.analytics.emit(signal, data);
                };
                player.onAnalytics(analytics_callback);
            }
        });
        
        this.onObserverEnter(function(observer) {
            log.info(observer.name + " has joined "+ self.id + " using unique id as an OBSERVER" + observer.network_id);
            
            if(!observer.hasEnteredGame) {
                self.incrementObserverCount();
            }

            observer.onBroadcast(function(message, ignoreSelf) {
                this.socket.broadcast.json.send(message.serialize());
            });
                        
            // Number of observers in this game
            self.pushToPlayer(observer, new Messages.Population(self.observerCount,self.maxObservers));
            self.pushRelevantEntityListTo(observer);

            observer.onExit(function() {
                log.info(observer.name + " has left the game as an OBSERVER.");
                self.removeObserver(observer);
                self.decrementObserverCount();
                
                if(self.removed_callback) {
                    self.removed_callback();
                }
                this.analytics_callback('messages', { 
                     'observers' : Object.keys(self.observers).length, 
                });
            });
            
            if(self.added_callback) {
                self.added_callback();
            }
        });
    },
    
    run: function(mapFilePath) {
        var self = this;  
        
        log.info(""+this.id+" created (capacity: "+this.maxPlayers+" players)."); 
    },
    
    onPlayerConnect: function(callback) {
        this.connect_callback = callback;
    },

    onObserverConnect: function(callback) {
        this.watch_callback = callback;
    },
    
    onPlayerEnter: function(callback) {
        this.enter_callback = callback;
    },

    onObserverEnter: function(callback) {
        this.observer_enter_callback = callback;
    },
        
    updatePopulation: function(totalPlayers) {
        //this.pushBroadcast(new Messages.Population(this.playerCount, totalPlayers ? totalPlayers : this.playerCount));
        log.debug('Game.updatePopulation() totalPlayer :' + (totalPlayers ? totalPlayers : this.playerCount));
    },
    
    addEntity: function(entity) {
        var self = this;
        
        this.entities[entity.network_id] = entity;
        _.each(this.players, function(player){
            if (player.network_id != entity.belongs_to)
                self.pushToPlayer(player, new Messages.Spawn(entity));
        });
    },
 
    updateEntity: function(entity,operationTime,changes) {
        var self = this;
        var obj = JSON.parse(changes);
        log.debug("updateEntity typeof obj:"+typeof obj);
        if (obj) {
            if(typeof obj === 'object') {
                entity.extend(obj)          
            }
            _.each(this.players, function(player){
                if (player.network_id != entity.belongs_to)
                    self.pushToPlayer(player, new Messages.Update(entity,operationTime,changes));
            });             
        } 
    },
       
    addPlayer: function(player) {
        // we want players as Joueur entities
        this.addEntity(player);
        this.players[player.network_id] = player;
    },
 
    removeEntity: function(entity) {
        if(entity.network_id in this.entities) {
            delete this.entities[entity.network_id];
        }
        
        entity.destroy();
        log.debug("Removed "+ Types.getKindAsString(entity.kind) +" : "+ entity.network_id);
    },
    
    removePlayerEntities: function(player) {
        var self = this;
        
        if(player) {
            entities = _.filter(self.entities, function(entity) { return entity.belongs_to == player.network_id; });
            if(entities) {
                self.pushDespawnsToPlayers(player,entities);
                _.each(entities, function(entity) {
                    self.removeEntity(entity);
                });
            }
        } 
        
        self.blocks = [];       
    },
    
    removePlayer: function(player) { 
        // some entities belong to players, we must despawn and remove them
        this.removePlayerEntities(player);
        //player.broadcast(player.despawn());
        this.removeEntity(player);
        delete this.players[player.network_id];
    },
    
    getEntityById: function(id) {
        if(id in this.entities) {
            return this.entities[id];
        } else {
            log.error("Unknown entity : " + id);
        }
    },
    
    getPlayerIndex: function() {
        var i = 0;
        for(i = 0; i < this.playerCount; i++){
            var found = _.find(this.players, function(player) {
                return player.index == i;
            });
            if (!found) return i;
        }
        return this.playerCount;
    },
    
    setPlayerCount: function(count) {
        this.playerCount = count;
    },
       
    incrementPlayerCount: function() {
        this.setPlayerCount(this.playerCount + 1);
    },
    
    decrementPlayerCount: function() {
        if(this.playerCount > 0) {
            this.setPlayerCount(this.playerCount - 1);
        }
    },
    
    _createId: function() {
        return '5' + this._uniqueness + '' + (this._counter++);
    },
    
    getId: function() {
        return this._createId();
    },
    
    pushToPlayer: function(player, message) {
        if(player) {
            player.send(message.serialize());
        } else {
            log.error("pushToPlayer: player was undefined");
        }
    },
    
    pushRelevantEntityListTo: function(player) {
        var entities;
        
        if(player) {
            entities = _.keys(this.entities);
            entities = _.reject(entities, function(id) { return id == player.network_id; });
            entities = _.map(entities, function(id) { return parseInt(id); });
            log.info("Pushed "+_.size(entities)+" entities to players");
            if(entities) {
                this.pushToPlayer(player, new Messages.List(entities));
            }
        }
    },
 
    pushRelevantEntityTo: function(player) {
        var entities;
        var self = this;
        
        if(player) {
            entities = _.keys(this.entities);
            entities = _.reject(entities, function(id) { return id == player.network_id; });
            entities = _.map(entities, function(id) { return parseInt(id); });
            log.debug("Pushed "+_.size(entities)+" entities to players");
            if(entities) {
                _.each(entities, function(id) {
                    var entity = self.getEntityById(id);
                    if(entity) {
        				var msg = new Messages.Spawn(entity);
        				log.debug("pushEntityToPlayer: msg " + JSON.stringify(msg));
                        self.pushToPlayer(player, msg);
                    }
                });

            }
        }
    },
    
    pushSpawnsToPlayer: function(player, ids) {
        var self = this;
        
        _.each(ids, function(id) {
            var entity = self.getEntityById(id);
            if(entity) {
				var msg = new Messages.Spawn(entity);
                seen = []
				log.debug("pushSpawnsToPlayer: msg " + JSON.stringify(msg, function(key, val) {
                   if (typeof val == "object") {
                        if (seen.indexOf(val) >= 0)
                            return
                        seen.push(val)
                    }
                    return val
                }));
                seen = null;
                self.pushToPlayer(player, msg);
            }
        });
        
        log.debug("Pushed "+_.size(ids)+" new spawns to "+player.network_id);
    }, 
    
    pushDespawnsToPlayers: function(from,entities) {
        var self = this;
        
        _.each(entities, function(entity) {
            from.broadcast(new Messages.Despawn(entity));
        });
        
        log.debug("Pushed "+_.size(entities)+" despawns to players");
    },
    
    isValidPosition: function(index) {
        return true;
    },   
	
	getTime: function() {
		return (new Date().getTime() - this.startTime);
	},
    
    blockOp: function(id, action, message) {
        this.blocks.push({ "id" : id, "action" : action, "message" : message});
    },
    
    pushRelevantBlockListTo: function(player) {
        var self = this;
        var blocks;
        
        if(player) {
            blocks = this.blocks;
            //blocks = _.reject(blocks, function(id) { return id == player.network_id; });
            //blocks = _.map(blocks, function(id) { return parseInt(id); });
            if(blocks) {
                log.info("Pushed "+_.size(blocks)+" bloc/debloc to players");
                _.each(blocks, function(block) {
                    log.debug("Sending block: "+JSON.stringify(block));
                    self.pushToPlayer(player, block["message"]);
                });
            }
        }
    }
});