// Read the surrounding magnetic field and get the angle in a clockwise direction from North.
import SwiftIO
import MadBoard
import MAG3110

let i2c = I2C(Id.I2C0)
let sensor = MAG3110(i2c)

// Calibrate the sensor to offset the surrounding static magnetic field.
sensor.calibrate()

while true {
    let rawValue = sensor.readRawValues()
    print("x = \(rawValue.x), y = \(rawValue.y), z = \(rawValue.z)")
    sleep(ms: 1000)
    print("Heading: \(getFloatString(sensor.readHeading()))")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}