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
	, Generic = require('./generic')
	, Reference = require('./reference')
	, sleep = require('sleep')
	, config = require('../config')
	, Types = require("./gametypes");

Object.defineProperty(Object.prototype, "extend", {
    enumerable: false,
    value: function(from) {
        var props = Object.getOwnPropertyNames(from);
        var dest = this;
        props.forEach(function(name) {
            //if (name in dest) {
                var destination = Object.getOwnPropertyDescriptor(from, name);
                Object.defineProperty(dest, name, destination);
				//}
        });
        return this;
    }
});

module.exports = Player = Entity.extend({
    init: function(socket, domain, gameServer) {
        log.debug("player.init "); 
        var self = this;
        
        this.server = gameServer;
        this.socket = socket;
        this.domain = domain;
        this.belongs_to = this;
        
        this._super(this.server.getId(), null);
        log.debug("player unique id is " + this.network_id);
		        
        this.hasEnteredGame = false;
        this.onAnalytics(function(player) {
        });
        this.factory = {
			'Brixtron' : require("./brixtron"),
			'ArbreCoupe' : require("./arbrecoupe")
		}
		
        this.socket.on('message', function (message, callbackfn){
            try 
            {
                log.debug("Player.on.message [" + message + "]"); 
                var action = parseInt(message[0]),
    				reseauTime = parseFloat(message[1]),
                    operationTime = parseFloat(message[2]);
            
                if(action === Types.Messages.HELLO) {
                    log.debug("Player.on.message HELLO");
                
                    self.name = message[3];
                    // index is first free slot from 0 to server.playerCount
                    self.index = self.server.getPlayerIndex();
                    if (self.name == null) 
                    {
                        self.name = 'Player ' + (self.index+1);
                    }
                    self.server.addPlayer(self);
                    self.send([Types.Messages.WELCOME, self.index, self.network_id, self.name]); 
                    self.server.enter_callback(self);   
                    self.hasEnteredGame = true;         
                } 
                else if(action == Types.Messages.SPAWN){
    				log.info("Player.on.message [" + message + "]"); 
    				obj = JSON.parse(message[3], function (key, value) {
    				    if (value && typeof value === 'object') {
    						if ('$type' in value) {
    							var new_type = value['$type'].split(',')[0];
    							// do we have a factory to build a specific for this object type
    							if (new_type in self.factory) {
    								var new_value = new self.factory[new_type](self.server.getId(), self.network_id, value);
    						        //spawn_type = value['$type'];
    				                log.debug("Player.on.message SPAWN type = " + new_type.type + " object = " + new_value); 
    								return new_value;
    							} else {
    								//create a generic
    								var new_value = new Generic(self.server.getId(), self.network_id, value);
    								log.debug("Player.on.message SPAWN type = GENERIC object = " + new_value);
    								return new_value; 
    							}
    						} else { // probably a $network_ref
    							var new_value = new Reference(value);
    							return new_value;
    						}

    				    }
    				    return value;
    				});
                    self.server.addEntity(obj)
    				log.debug("Player.on.message returning network_id: " + obj.network_id); 
    				if (config.latency) {
    					sleep.usleep(20000);
    				}
                    callbackfn(obj.network_id);
                }
                else if(action === Types.Messages.DESPAWN) {
                    var id = message[3],
                        entity = self.server.getEntityById(id); 
				
                    if (entity){
        				log.debug("Player.on.message DESPAWN id = " + id);	      
        		        _.each(self.server.players, function(player){
        		            if (player.network_id != self.network_id)
        		                self.server.pushToPlayer(player, new Messages.Despawn(entity));
        		        });           
                        self.server.removeEntity(entity);
                    } 
                }
                else if(action === Types.Messages.WHO) {
                    var ids = message.slice(3);
                    log.debug("Player.on.message Types.Messages.WHO received entities: " + ids); 
                    self.server.pushSpawnsToPlayer(self, ids);
                    self.server.pushRelevantBlockListTo(self);
                    //self.server.pushRelevantEntityTo(self);
                }
                else if(action === Types.Messages.PLANMOVE) {
                    if(self.move_callback) {
                        log.debug("Player.on.message Types.Messages.PLANMOVE operationTime: " + operationTime + " Reseau.time: " + reseauTime + " server time: " + self.server.getTime()/1000.0); 
                        var id = message[3],        
                            index = message[4],
                            validated = message[5],
                            cancellation_level = message[6];
                            entity = self.server.getEntityById(id);
                    
                        if(self.server.isValidPosition(index)) {                        
                            self.broadcast(new Messages.PlanMove(entity,operationTime,index,validated,cancellation_level));
                            self.move_callback(entity,operationTime,index,validated,cancellation_level);
                        }
                    }
                }
                else if(action === Types.Messages.CLEAR) {
                    var id = message[3],
                        entity = self.server.getEntityById(id); 
					                 
                    self.broadcast(new Messages.Clear(entity,operationTime));
                }
                else if(action === Types.Messages.CHOP) {
                    var id = message[3],
    					index = message[4],
                        entity = self.server.getEntityById(id); 
					                 
                    self.broadcast(new Messages.Chop(entity,operationTime,index));
                } 
                else if(action === Types.Messages.MODE) {
                    var id = message[3],
    					mode = message[4], 
                        entity = self.server.getEntityById(id); 
					                 
                    self.broadcast(new Messages.Mode(entity,operationTime,mode));
                } 
                else if(action == Types.Messages.TIME){
    				var currentTime = self.server.getTime()/1000.0;
    				if (config.latency) {
    					sleep.usleep(20000);
    				}
                    callbackfn(reseauTime,currentTime);
                } 
                else if(action == Types.Messages.ACTION){
                    var id = message[3],
    					instructions = message[4],
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message ACTION id:"+id+" instructions:"+JSON.stringify(instructions));	                 
                    self.broadcast(new Messages.Action(entity,operationTime,instructions));
                } 
                else if(action == Types.Messages.DEBLOC){
                    var pos = message[3],
    					real = message[4],
    					gravity = message[5]
					
    				log.debug("Player.on.Message DEBLOC pos:"+pos+" real:"+real+" gravity:"+gravity);
                    // store BLOC/DEBLOC operations for updating joining players
                    var newMessage = new Messages.DeBloc(pos,real,gravity);
                    self.server.blockOp(self.network_id, action, newMessage);	                 
                    self.broadcast(newMessage);
                } 
                else if(action == Types.Messages.BLOC){
                    var index = message[3],
    					paire = message[4],
    					type = message[5],
    					variante = message[6],
    					niveaux = message[7]
					
    				log.debug("Player.on.Message BLOC index:"+index+" paire:"+paire+" type:"+type+" variante:"+variante+" niveaux:"+niveaux);
                    // store BLOC/DEBLOC operations for updating joining players
                    var newMessage = new Messages.Bloc(index,paire,type,variante,niveaux);	
                    self.server.blockOp(self.network_id, action, newMessage);                 
                    self.broadcast(newMessage);
                } 
                else if(action == Types.Messages.EQUIP){
                    var id = message[3],
                        mode = message[4],
    					type = message[5],
    					count_or_id = message[6],
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message EQUIP id:"+id+" mode:"+mode+" type:"+type+" count_or_id:"+count_or_id);	                 
                    self.broadcast(new Messages.Equip(entity,operationTime,mode,type,count_or_id));
                } 
                else if(action == Types.Messages.UNEQUIP){
                    var id = message[3],
    				    item = message[4],
    				    count = message[5],
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message UNEQUIP id:"+id+" item:"+item+" count:"+count);	                 
                    self.broadcast(new Messages.Unequip(entity,operationTime,item,count));
                } 
                else if(action == Types.Messages.UPDATE){
                    var id = message[3],
                        changes = message[4],
                        entity = self.server.getEntityById(id); 
                    
    				log.debug("Player.on.Message UPDATE id:"+id+" entity:"+JSON.stringify(entity)+" changes:"+changes);
                    // update server entity
                    self.server.updateEntity(entity,operationTime,changes);	                 
                } 
                else if(action == Types.Messages.ADD){
                    var id = message[3],
    					item = message[4],
                        into = message[5]
                        entity = self.server.getEntityById(id); 
                        recipient = self.server.getEntityById(into); 
				
    				log.debug("Player.on.Message ADD id:"+id+" item:"+item+" into:"+into);	                 
                    self.broadcast(new Messages.Add(entity,operationTime,item,recipient));
                } 
                else if(action == Types.Messages.HIT){
                    var id = message[3]
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message HIT id:"+id);	                 
                    self.broadcast(new Messages.Hit(entity));
                } 
                else if(action == Types.Messages.AIM){
                    var id = message[3],
    					target = message[4]
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message AIM id:"+id+" target:"+target);	                 
                    self.broadcast(new Messages.Aim(entity, operationTime, target));
                } 
                else if(action == Types.Messages.PATH){
                    var id = message[3],
    					path_action = message[4],
                        data = message[5],
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message PATH id:"+id+" action:"+action+" data:"+JSON.stringify(data));	                 
                    self.broadcast(new Messages.Path(entity, operationTime, path_action, data));
                }
                else if(action == Types.Messages.DAMAGE){
                    log.info("Player.on.message [" + message + "]"); 
                    var id = message[3],
                        mode = message[4],
    					from = message[5],
                        data = message[6],
                        entity = self.server.getEntityById(id); 
				
    				log.debug("Player.on.Message DAMAGE id:"+id+" mode: "+mode+" from:"+from+" data:"+JSON.stringify(data));	                 
                    self.broadcast(new Messages.Damage(entity, operationTime, mode, from, data));
                }
                else {
                    if(self.message_callback) {
                        self.message_callback(message);
                    }
                }
                ip = self.socket.handshake.address.address;
                ctx = { 
                    'from' : self.name,
                    'connections' : Object.keys(self.server.players).length, 
                    'msg' : message, 
                    //'players' : self.server.players, 
                    'action' : Types.getMessageAsString(action), 
                    'timestamp': (self.server.getTime() / 1000.0),
                }
                self.analytics_callback('messages', ctx);
                log.debug("Player.on.Message ctx"+JSON.stringify(ctx));	 
            }
            catch(err) {
                log.error("Play.on.message exception err:"+err);
            }
        });
        
        this.socket.on('disconnect', function (){ 
            log.debug("Player.on.disconnect");
            if(self.exit_callback) {
                self.exit_callback();
            }
        });
        
    },

    onBroadcast: function(callback) {
        this.broadcast_callback = callback;
    },
     
    onMessage: function(callback) {
        this.message_callback = callback;
    },
    
    onMove: function(callback) {
        this.move_callback = callback;
    },
    
    onPlanMove: function(callback) {
        this.plan_move_callback = callback;
    },
    
    onAnalytics: function(callback) {
        this.analytics_callback = callback;
    },
       
    send: function(message) {
        this.socket.json.send(message);
    },
  
    broadcast: function(message, ignoreSelf) {
        if(this.broadcast_callback) {
            this.broadcast_callback(message, ignoreSelf === undefined ? true : ignoreSelf);
        }
    },
    
    onExit: function(callback) {
        this.exit_callback = callback;
    },  
    
    getState: function() {
        var object = { 
            "network_id" : this.network_id, 
            "index" : this.index,
            "nom" : this.name,
            "$type": "Joueur, Assembly-UnityScript"
        }
        return object;
    },
});