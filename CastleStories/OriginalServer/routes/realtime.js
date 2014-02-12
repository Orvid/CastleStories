
/*
 * GET realtime page.
 */
var version = require('./version')

exports.overview = function (req, res) {  
  res.render ('overview', function(err, html) {
    res.render ('index', {
        version: version,
        title: 'CastleStory/MP',
        content: html,  
        menu: 'realtime',
        submenu: 'overview',
        extrajs: [ 
            '/socket.io/socket.io.js',
            "http://code.highcharts.com/highcharts.js",
            "/js/realtime.js"
        ]
    });
  });
}
