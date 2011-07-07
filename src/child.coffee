net = require 'net'
util = require 'util'
events = require('events')

socket = new net.Socket()


Child = () ->
  events.EventEmitter.call(@)
  this.fly()

util.inherits Child, events.EventEmitter

Child.prototype.fly = () ->
  cntr = 0
  socket.connect process.env['_HIPPOGRIFF_SOCKET'], () ->
    socket.write "HELLO MY NAME IS #{process.pid}" + '\n'
    socket.on 'data', (data) ->
      data = data.toString()
      lines = data.split '\n'
      for line in lines
        if line == 'PING'
          if cntr == 0
            socket.write("PONG #{process.pid}" + '\n')
            # cntr++


Child.prototype.land = () ->
  socket.write("GOODBYE FROM #{process.pid}" + '\n')
  socket.end()
  callback = (code) -> process.exit code
  this.emit "exit", callback
  


module.exports = Child