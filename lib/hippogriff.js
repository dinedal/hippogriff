(function() {
  var Hippogriff, events, net, util;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  net = require('net');
  util = require('util');
  events = require('events');
  Hippogriff = function() {
    events.EventEmitter.call(this);
    return this.fly();
  };
  util.inherits(Hippogriff, events.EventEmitter);
  Hippogriff.prototype.fly = function() {
    var cntr;
    cntr = 0;
    process.on("SIGQUIT", function() {});
    net.createServer(__bind(function(socket) {
      this.socket = socket;
      return socket.on('data', __bind(function(data) {
        var line, lines, _i, _len, _results;
        console.log("" + process.pid + " - Got Data " + (data.toString()));
        data = data.toString();
        lines = data.split('\n');
        _results = [];
        for (_i = 0, _len = lines.length; _i < _len; _i++) {
          line = lines[_i];
          if (line === 'PING') {
            if (cntr === 0) {
              socket.write(("PONG " + process.pid) + '\n');
            }
          }
          _results.push(line === ("GO AWAY " + process.pid) ? (console.log("okay"), this.land()) : void 0);
        }
        return _results;
      }, this));
    }, this)).listen(process.env['_HIPPOGRIFF_SOCKET']);
    return process.nextTick(function() {
      var master_socket;
      master_socket = new net.Socket();
      console.log(process.env['_HIPPOGRIFF_MASTER_SOCKET']);
      return master_socket.connect(process.env['_HIPPOGRIFF_MASTER_SOCKET'], function() {
        console.log("writing hello");
        master_socket.write(("HELLO MY NAME IS " + process.pid) + '\n');
        return master_socket.end();
      });
    });
  };
  Hippogriff.prototype.land = function() {
    var callback, self;
    self = this;
    console.log("" + process.pid + " - Landing! @socket.writable? " + (util.inspect(this.socket.writable)));
    callback = __bind(function(code) {
      code || (code = 0);
      console.log("Callback called " + this.socket.writable);
      if ((this.socket != null) && this.socket.writable) {
        this.socket.write(("GOODBYE FROM " + process.pid) + '\n');
      }
      this.socket.end();
      return process.exit(code);
    }, this);
    return this.emit("exit", callback);
  };
  module.exports = Hippogriff;
}).call(this);
