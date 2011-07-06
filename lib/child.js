(function() {
  var net, socket, util;
  net = require('net');
  util = require('util');
  socket = new net.Socket();
  exports.fly = function() {
    var cntr;
    cntr = 0;
    return socket.connect(process.env['_HIPPOGRIFF_SOCKET'], function() {
      socket.write(("HELLO MY NAME IS " + process.pid) + '\n');
      return socket.on('data', function(data) {
        var line, lines, _i, _len, _results;
        data = data.toString();
        lines = data.split('\n');
        _results = [];
        for (_i = 0, _len = lines.length; _i < _len; _i++) {
          line = lines[_i];
          _results.push(line === 'PING' ? cntr === 0 ? socket.write(("PONG " + process.pid) + '\n') : void 0 : void 0);
        }
        return _results;
      });
    });
  };
  exports.land = function() {
    socket.write(("GOODBYE FROM " + process.pid) + '\n');
    return socket.end();
  };
}).call(this);
