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
    Utils = require("./utils")
    
module.exports = Analytics = cls.Class.extend({
    init: function(maxRT, websocketServer, domain) {
        var self = this;

        this.maxRT = maxRT;
        this.server = websocketServer;
        this.rtCount = 0;
        this.domain = domain;
        
        this.onRTConnect(function(analyst) {
            log.debug('Analytics.onPRTConnect called for analyst ' + analyst)
        });
        
        this.onRTDisplay(function(analyst) {
            
            analyst.onBroadcast(function(message, ignoreSelf) {
                this.domain.emit(message);
            });
                        
            analyst.onExit(function() {
            });
        });
    },
    
    emit: function(signal, data) {
        log.debug('Analytics.emit() signal: ' + signal + " data: " + data);
        this.domain.emit(signal, data);
    },
        
    onRTConnect: function(callback) {
        this.connect_callback = callback;
    },

    onRTDisplay: function(callback) {
        this.display_callback = callback;
    },    
});