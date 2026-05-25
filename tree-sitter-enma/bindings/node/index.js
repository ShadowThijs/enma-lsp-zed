module.exports = require("node-gyp-build")(__dirname);
try {
  module.exports.nodeTypeInfo = require("./src/node-types.json");
} catch (_) {}
