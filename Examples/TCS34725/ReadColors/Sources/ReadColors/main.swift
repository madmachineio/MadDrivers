// Read color values every second.
import SwiftIO
import MadBoard
import TCS34725

let i2c = I2C(Id.I2C0)
let sensor = TCS34725(i2c)

sensor.setIntegrationTime(150)

while true {
    print(sensor.readRaw())
    print("Lux: \(sensor.readLux())")
    print("Color temperature: \(sensor.readColorTemperature())")
    print("Color code: \(String(sensor.readColorCode(), radix: 16))")
    sleep(ms: 1000)
}