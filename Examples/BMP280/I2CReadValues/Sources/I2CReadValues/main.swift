// Read the temperature, barometric pressure and altitude every 2s.
import SwiftIO
import BMP280
import MadBoard

let i2c = I2C(Id.I2C0)
let sensor = BMP280(i2c)

while true {
    let temp = sensor.readTemperature()
    let pressure = sensor.readPressure()
    // Set the current sea level pressure to get a accurate altitude.
    let altitude = sensor.readAltitude(1020)
    
    print("tmeperature: \(temp)")
    print("pressure: \(pressure)")
    print("altitude: \(altitude)")

    sleep(ms: 2000)
}
