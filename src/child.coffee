net = require 'net'
util = require 'util'

socket = new net.Socket()

exports.fly = () ->
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


exports.land = () ->
  socket.write("GOODBYE FROM #{process.pid}" + '\n')
  socket.end()