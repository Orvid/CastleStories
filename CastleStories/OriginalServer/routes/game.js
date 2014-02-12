var games = [{
    _id: 1,
    name: "defaultGame",
    country: "Canada",
    region: "Montreal",
    description: "This is the default game",
    picture: null
}];

exports.index = function(req, res){
  res.send(games);
};

exports.new = function(req, res){
  res.send('new game');
};

exports.create = function(req, res){
  res.send('create game');
};

exports.show = function(req, res){
  res.send(games);
};

exports.edit = function(req, res){
  res.send('edit game ' + req.params.game);
};

exports.update = function(req, res){
  res.send('update game ' + req.params.game);
};

exports.destroy = function(req, res){
  res.send('destroy game ' + req.params.game);
};