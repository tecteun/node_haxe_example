var fs = require('fs');
var util = require('util');
var xml4js = require('xml4js');
 
// Most of xml2js options should still work 
var options = {};
var parser = new xml4js.Parser(options);
 
// Default is to not download schemas automatically, so we should add it manually 
var schema = fs.readFileSync('vmap.xsd', {encoding: 'utf-8'});
parser.addSchema('http://www.example.com/Schema', schema, function (err, importsAndIncludes) {
    // importsAndIncludes contains schemas to be added as well to satisfy all imports and includes found in schema.xsd 
    parser.parseString(xml, function (err, result) {
        console.log(util.inspect(result, false, null));
    });
});
