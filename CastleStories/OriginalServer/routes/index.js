
/*
 * GET home page.
 */
var version = require('./version')

exports.index = function (req, res) {  
  res.render ('home', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'home',
        submenu: null,
        extrajs: []
    });
  });
}