Hippogriff = require '/Users/pbergeron/Sites/hippogriff/src/hippogriff'


console.log "Starting..."
hippogriff = new Hippogriff()
setTimeout (() -> 
  console.log "Done!"
  hippogriff.land()
), 10000

hippogriff.on 'exit', (callback) ->
  callback 0
  