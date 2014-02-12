exports.findAll = function(req, res) {
    res.send([{name:'player1'}, {name:'player2'}, {name:'player3'}]);
};

exports.findById = function(req, res) {
    res.send({id:req.params.id, name: "The Name", description: "description"});
};