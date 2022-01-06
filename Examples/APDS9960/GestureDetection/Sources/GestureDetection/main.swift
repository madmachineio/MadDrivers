// Read and print the detected gesture.
import SwiftIO
import MadBoard
import APDS9960

let i2c = I2C(Id.I2C1)
let sensor = APDS9960(i2c)

// Enable Proximity and gesture detection before reading data.
sensor.enableProximity()
sensor.enableGesture()

while true {
    let gesture = sensor.readGesture()
    
    if gesture != .noGesture {
        print(gesture) 
    }
}
