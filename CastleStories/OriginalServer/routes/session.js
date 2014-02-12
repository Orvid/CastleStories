
/*
 * GET sessions page.
 */

var version = require('./version')

exports.current = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'sessions',
        submenu: 'current',
        extrajs: []
    });
  });
};

exports.persistent = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'sessions',
        submenu: 'persistent',
        extrajs: []
    });
  });
};

exports.recorded = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'sessions',
        submenu: 'recorded',
        extrajs: []
    });
  });
};  