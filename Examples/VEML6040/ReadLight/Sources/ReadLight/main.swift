// Read red, green, blue and white color data and the light intensity.
// You can infer the color of objects by comparing the RGB values.
import SwiftIO
import MadBoard
import VEML6040

let i2c = I2C(Id.I2C0)
let sensor = VEML6040(i2c)

while true {
    print("Red: \(sensor.readRedRawValue())")
    print("Green: \(sensor.readGreenRawValue())")
    print("Blue: \(sensor.readBlueRawValue())")
    print("White: \(sensor.readWhiteRawValue())")
    print("Lux: \(sensor.readLux())")
    sleep(ms: 1000)
}