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
    _ = require("underscore");

module.exports = Analyst = cls.Class.extend({
    init: function(socket, domain, analytics) {
        log.debug("analyst.init "); 
        var self = this;
        
        this.analytics = analytics;
        this.socket = socket;
        this.domain = domain;
        
        this.socket.on('disconnect', function (){ 
            log.debug("Analyst.on.disconnect");
            if(self.exit_callback) {
                self.exit_callback();
            }
        });
    },

    onBroadcast: function(callback) {
        this.broadcast_callback = callback;
    },
    
    send: function(message) {
        this.domain.emit(message);
    },
  
    broadcast: function(message, ignoreSelf) {
        if(this.broadcast_callback) {
            this.broadcast_callback(message, ignoreSelf === undefined ? true : ignoreSelf);
        }
    },
    
    onExit: function(callback) {
        this.exit_callback = callback;
    },  
});