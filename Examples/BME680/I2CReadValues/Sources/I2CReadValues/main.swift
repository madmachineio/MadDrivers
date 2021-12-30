import SwiftIO
import MadBoard
import BME680

let i2c = I2C(Id.I2C1)
let sensor = BME680(i2c)

while true {
    print("Temperature: \(sensor.readTemperature())")
    print("Humiture: \(sensor.readHumidity())")
    print("Pressure: \(sensor.readPressure())")
    print("Gas: \(sensor.readGasResistance())")
    sleep(ms: 2000)
}
