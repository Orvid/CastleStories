
/*
 * GET maps page.
 */

var version = require('./version')

exports.maps = function (req, res) {  
  res.render ('maps', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,
        menu: 'maps',
        submenu: null,
        extrajs: []
    });
  });
};
