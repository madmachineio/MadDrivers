// Read and print the detected gesture.
import SwiftIO
import MadBoard
import APDS9960

let i2c = I2C(Id.I2C0)
let sensor = APDS9960(i2c)

// Enable Proximity and gesture detection before reading data.
sensor.enableProximity()
sensor.enableGesture()

while true {
    let gesture = sensor.readGesture()
    
    if gesture != .noGesture {
        printGesture(gesture) 
    }
}

func printGesture(_ gesture: APDS9960.Gesture) {
    let string: String

    switch gesture {
        case .noGesture:
        string = "No Gesture"
        case .up:
        string = "Up"
        case .down:
        string = "Down"
        case .left:
        string = "Left"
        case .right:
        string = "Right"
    }
}