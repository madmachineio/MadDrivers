import SwiftIO
import MadBoard
import MPL3115A2

let i2c = I2C(Id.I2C0)
let sensor = MPL3115A2(i2c)

while true {
    print("Pressure: \(sensor.readPressure()) Pa")
    print("Altitude: \(sensor.readAltitude()) m")
    print("Temperature: \(sensor.readTemperature()) C")
    sleep(ms: 1000)
}

