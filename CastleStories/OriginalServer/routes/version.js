var version = {}
  , fs = require('fs')

String.format = function() {
    // The string containing the format items (e.g. "{0}")
    // will and always has to be the first argument.
    var theString = arguments[0];

    // start with the second argument (i = 1)
    for (var i = 1; i < arguments.length; i++) {
        // "gm" = RegEx options for Global search (more than one instance)
        // and for Multiline search
        var regEx = new RegExp("\\{" + (i - 1) + "\\}", "gm");
        theString = theString.replace(regEx, arguments[i]);
    }

    return theString;
}
  
function getVersionFile(path, callback) {
    fs.readFile(path, 'utf8', function(err, json_string) {
        if(err) {
            console.error("Could not open version file:", err.path);
            callback(null);
        } else {
            callback(JSON.parse(json_string));
        }
    });
};

getVersionFile('./version.json', function(_version){
    version['long'] = String.format("{0}.{1}.{2}.{3}", _version['release'], _version['major'], _version['minor'], _version['rev']);
});

module.exports = version;