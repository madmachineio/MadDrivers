// Read color values every second.
import SwiftIO
import MadBoard
import TCS34725

let i2c = I2C(Id.I2C0)
let sensor = TCS34725(i2c)

sensor.setIntegrationTime(150)

while true {
    let rawValue = sensor.readRaw()
    print("Rawvalue: red = \(rawValue.red), green = \(rawValue.green), blue = \(rawValue.blue), clear = \(rawValue.clear)")
    print("Lux: \(getFloatString(sensor.readLux()))")
    print("Color temperature: \(getFloatString(sensor.readColorTemperature()))")
    print("Color code: \(sensor.readColorCode()), radix: 16")
    sleep(ms: 1000)
}


func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}