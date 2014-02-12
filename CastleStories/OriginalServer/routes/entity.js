
/*
 * GET entities page.
 */

var version = require('./version')

exports.spawned = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'entities',
        submenu: 'spawned',
        extrajs: []
    });
  });
};

exports.blocks = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'entities',
        submenu: 'blocks',
        extrajs: []
    });
  });
};