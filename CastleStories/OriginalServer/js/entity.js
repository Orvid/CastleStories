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

var cls = require("./lib/class");

module.exports = Entity = cls.Class.extend({
    init: function(id, belongs_to) {
		this.network_id = parseInt(id);
        this.belongs_to = belongs_to;
    },
    
    destroy: function() {
    },

    _getBaseState: function() {
        return [
            parseInt(this.network_id),
        ];
    },
    
    getState: function() {
        return this._getBaseState();
    },
        
    spawn: function() {
        return new Messages.Spawn(this);
    },
    
    despawn: function() {
        return new Messages.Despawn(this);
    },

});