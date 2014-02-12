var BSON = require('mongodb').pure().BSON;
var fs = require('fs');
var Buffer = require('buffer').Buffer;
var constants = require('constants');
var stats;

describe('bson', function(){

  it('should pass', function(){
    expect(1+2).toEqual(3);
  });
  
  it('should read product.json file', function(){
      fs.readFile('specs/product.json', 'utf8', function (err, data) {
        if (err) {
          console.log('Error: ' + err);
          return;
        }

        data = JSON.parse(data);
        //console.log(data);
        expect(data.Sizes.Length == 3);
      });
   });
   
   it('should read product.bson file', function(){
       fs.readFile('specs/product.bson', function (err, data) {
         if (err) {
           console.log('Error: ' + err);
           return;
         }

         //console.log(data);
         bson = new BSON();
         data = bson.deserialize(data);
         //console.log(data);
         expect(data.Sizes.Length == 3);
       });
    });
});
