// Read current light intensity in lux and print it out.
import SwiftIO
import MadBoard
import BH1750

let i2c = I2C(Id.I2C0)
let sensor = BH1750(i2c)

while true {
    let luxString = getFloatString(sensor.readLux())
    print("Lux: " + luxString)
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}