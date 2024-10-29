// Read UV and ambient light values and print them every 2s.
import SwiftIO
import MadBoard
import LTR390

let i2c = I2C(Id.I2C0)
let sensor = LTR390(i2c)

while true {
    print("UV: \(sensor.readUV()), UVI: \(getFloatString(sensor.readUVI()))")
    print("Light: \(sensor.readLight()), Lux: \(getFloatString(sensor.readLux()))")
    sleep(ms: 2000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}