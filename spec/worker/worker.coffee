hippogriff = require '/Users/pbergeron/Sites/hippogriff/src/child'


console.log "Starting..."
hippogriff.fly()
setTimeout (() -> 
  console.log "Done!"
  hippogriff.land()
), 5000