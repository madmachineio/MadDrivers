// Read the surrounding magnetic field and get the angle in a clockwise direction from North.
import SwiftIO
import MadBoard
import MAG3110

let i2c = I2C(Id.I2C1)
let sensor = MAG3110(i2c)

// Calibrate the sensor to offset the surrounding static magnetic field.
sensor.calibrate()

while true {
    print(sensor.readRawValues())
    sleep(ms: 1000)
    print(sensor.readHeading())
    sleep(ms: 1000)
}