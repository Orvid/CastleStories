
/*
 * GET settings page.
 */

var version = require('./version')

exports.games = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'settings',
        submenu: 'games',
        extrajs: []
    });
  });
}; 

exports.server = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'settings',
        submenu: 'server',
        extrajs: []
    });
  });
};