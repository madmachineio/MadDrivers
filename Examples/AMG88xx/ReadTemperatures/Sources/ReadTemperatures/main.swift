// Read temperature values of 8x8 pixels from the sensor.

import SwiftIO
import MadBoard
import AMG88xx

let i2c = I2C(Id.I2C0)
let sensor = AMG88xx(i2c)

while true {
    printPixels(sensor.readPixels())
    sleep(ms: 1000)
}

func printPixels(_ pixels: [Float]) {
    print("[")
    for index in 0..<pixels.count {
        print("\(getFloatString(pixels[index])),")
    }
    print("]")
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}