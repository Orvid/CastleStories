
/*
 * GET auth page.
 */

var version = require('./version')

exports.admins = function (req, res) {  
  res.render ('observers', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'auth',
        submenu: 'admins',
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
        menu: 'auth',
        submenu: 'server',
        extrajs: []
    });
  });
};     
