
/*
 * GET users listing.
 */

var version = require('./version')

exports.list = function(req, res){
  res.send("respond with a resource");
};

exports.players = function (req, res) {  
  res.render ('players', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'users',
        submenu: 'players',
        extrajs: [] 
    });
  });
};

exports.observers = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'users',
        submenu: 'observers',
        extrajs: []
    });
  });
};
