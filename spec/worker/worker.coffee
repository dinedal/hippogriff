Hippogriff = require '/Users/pbergeron/Sites/hippogriff/src/child'


console.log "Starting..."
hippogriff = new Hippogriff()
setTimeout (() -> 
  console.log "Done!"
  hippogriff.land()
), 5000

hippogriff.on 'exit', (callback) ->
  callback 0