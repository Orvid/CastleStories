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
    , Types = require("./gametypes");

module.exports = Observer = Entity.extend({
    init: function(socket, domain, gameServer) {
        log.debug("observer.init "); 
        var self = this;
        
        this.server = gameServer;
        this.socket = socket;
        this.domain = domain;
        
        this._super(this.server.getId(), null);
        log.debug("observer unique id is " + this.network_id);
        
        this.hasEnteredGame = false;
        
        this.socket.on('message', function (message, callbackfn){
            log.debug("Observer.on.message [" + message + "]"); 
            var action = parseInt(message[0]);
            
            if(action === Types.Messages.HELLO) {
                log.debug("Observer.on.message HELLO");
                
                self.name = message[1];
                // index is first free slot from 0 to server.playerCount
                self.index = self.server.getObserverIndex();
                if (self.name == null) 
                {
                    self.name = 'Observer ' + (self.index+1);
                }
                self.server.addObserver(self);
                self.send([Types.Messages.WELCOME, self.index, self.network_id, self.name]); 
                self.server.observer_enter_callback(self);   
                self.hasEnteredGame = true;         
            } 
            ip = self.socket.handshake.address.address;
            self.analytics_callback('messages', { 
                'connections' : Object.keys(self.server.players).length, 
                'msg' : message, 
                //'players' : self.server.players, 
                'action' : Types.getMessageAsString(action), 
                'timestamp': (self.server.getTime() / 1000.0).toFixed(3)
            });
        });
        
        this.socket.on('disconnect', function (){ 
            log.debug("Observer.on.disconnect");
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
        var basestate = this._getBaseState(),
            state = [];
        
        state.push(this.name);
        return basestate.concat(state);
    },
});