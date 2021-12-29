import SwiftIO
import MadBoard
import SHT3x

let i2c = I2C(Id.I2C0)
let sensor = SHT3x(i2c)

while true {
    print("Celcius: \(sensor.readCelsius())")
    print("Humidity: \(sensor.readHumidity())")
    sleep(ms: 1000)
}