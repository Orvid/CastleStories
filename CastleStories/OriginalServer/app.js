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

var express = require('express')
  , routes = require('./routes')
  , user = require('./routes/user')
  , realtime = require('./routes/realtime')
  , session = require('./routes/session')
  , map = require('./routes/map')
  , entity = require('./routes/entity')
  , setting = require('./routes/setting')
  , auth = require('./routes/auth')
  , http = require('http')
  , i18n = require('i18next')
  , fs = require('fs')
  , util = require('util')
  , log4js = require('log4js')
  , io = require('socket.io')
  , _ = require("underscore")
  , path = require('path');
    
  var Analytics = require("./js/analytics")
  , CastleServer = require("./js/castleserver")
  , Entity = require('./js/entity')
  , Player = require("./js/player")
  , Observer = require("./js/observer")
  , Analyst = require("./js/analyst")
  , Utils = require("./js/utils");

  var games = []
  , analytics = null;
  
function main(config) {
  i18n.init({
      saveMissing: true,
      debug: true
  });
  
  log = log4js.getLogger();
  switch(config.debug_level) {
      case "error":
          log.setLevel('ERROR'); break;
      case "debug":
          log.setLevel('DEBUG'); break;
      case "info":
          log.setLevel('INFO'); break;
  };
  log.info("Starting CastleStory MP server..."); 
  
  var app = express();

  app.configure(function(){
    app.set('port', process.env.PORT || config.port);
    app.set('views', __dirname + '/views');
    app.set('view engine', 'jade');
    app.use(express.favicon());
    app.use(express.logger('dev'));
    app.use(express.bodyParser());
    app.use(i18n.handle);
    app.use(express.methodOverride());
    app.use(app.router);
    app.use(require('less-middleware')({ src: __dirname + '/public' }));
    app.use(express.static(path.join(__dirname, 'public')));
  });

  i18n.registerAppHelper(app);

  app.configure('development', function(){
    app.use(express.errorHandler());
  });

  app.get('/', routes.index);
  app.get('/realtime/overview', realtime.overview);
  app.get('/users/players', user.players);
  app.get('/users/observers', user.observers);
  app.get('/users', user.list)
  app.get('/sessions/current', session.current);
  app.get('/sessions/persistent', session.persistent);
  app.get('/sessions/recorded', session.recorded);
  app.get('/maps', map.maps);
  app.get('/entities/spawned', entity.spawned);
  app.get('/entities/blocks', entity.blocks);
  app.get('/settings/games', setting.games);
  app.get('/settings/server', setting.server);
  app.get('/auth/admins', auth.admins);
  app.get('/auth/server', auth.server);
  
  var server = http.createServer(app);
  io = io.listen(server);
  io.set('log level', 1);

  io.configure(function () {
      io.set('authorization', function (handshakeData, callback) {
          //log.info("authorization - handshake data" + util.inspect(handshakeData))
          if (handshakeData.xdomain) {
              callback('Cross-domain connections are not allowed');
          } else {
              callback(null, true);
          }
      });
  });

  var play = io
      .of('/play')
      .on('connection', function (socket) {
          log.info("Someone connected to /play");
          var game, // the one in which the player will be spawned
              connect = function() {
                  if(game) {
                      game.connect_callback(new Player(socket, play, game));
                  }
              };
      
          // simply fill each world sequentially until they are full
          game = _.detect(games, function(game) {
              return game.playerCount < config.nb_players_per_game;
          });
          game.updatePopulation();
          connect();
  });
 
  var watch = io
      .of('/watch')
      .on('connection', function (socket) {
          log.info("Someone connected to /watch");
          var game, // the one in which the observer will be allowed to watch
              connect = function() {
                  if(game) {
                      game.watch_callback(new Observer(socket, play, game));
                  }
              };
      
          // simply fill each world sequentially until they are full
          game = _.detect(games, function(game) {
              return game.observerCount < config.nb_observers_per_game;
          });
          game.updatePopulation();
          connect();
  });
   
  var dashboard = io
      .of('/analytics')
      .on('connection', function (socket) {
          log.info("Someone connected to /analytics");
          var analytic,
              connect = function() {
                  if (analytic) {
                      analytic.connect_callback(new Analyst(socket, dashboard, analytic));
                  }
              };
              
          analytic = analytics;    
          connect();
  });
  
  server.listen(app.get('port'), function () {
      log.info("Express server listening on port " + app.get('port'));
  });
  
  if (config.metrics_enabled) {
      analytics = new Analytics(2,server,dashboard);
  }
  
  _.each(_.range(config.nb_games), function(i) {
      var game = new CastleServer('game'+ (i+1), config.nb_players_per_game, config.nb_observers_per_game, server, analytics);
      game.run(config.maps_path);
      games.push(game);
  }); 
  
  if (config.bonjour) {
      var mdns = require('mdns');
      var ad = mdns.createAdvertisement(mdns.tcp('http'), app.get('port'), {name: 'castlestory'});
      ad.start();
      log.info("castlestory server advertised using BONJOUR");
  } 
}

function getConfigFile(path, callback) {
    fs.readFile(path, 'utf8', function(err, json_string) {
        if(err) {
            console.error("Could not open config file:", err.path);
            callback(null);
        } else {
            callback(JSON.parse(json_string));
        }
    });
};

getConfigFile('./config.json', function(config){
    main(config);
});

process.on('uncaughtException', function(err) {
  log.error(err.stack);
});