import SwiftIO
import MadBoard
import MPL3115A2

let i2c = I2C(Id.I2C0)
let sensor = MPL3115A2(i2c)

while true {
    print("Pressure: \(getFloatString(sensor.readPressure())) Pa")
    print("Altitude: \(getFloatString(sensor.readAltitude())) m")
    print("Temperature: \(getFloatString(sensor.readTemperature())) C")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}