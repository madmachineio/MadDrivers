// Read light intensity and print the value every second.

import SwiftIO
import MadBoard
import TSL2591

let i2c = I2C(Id.I2C0)
let sensor = TSL2591(i2c)

while true {
    // Read total light intensity in lux. 
    print("Lux: \(getFloatString(sensor.readLux()))")
    // Read raw values. 
    // The full spectrum light includes IR and visible, so its value should be close to their sum. 
    print("IR: \(sensor.readIR())")
    print("Visible: \(sensor.readVisible())")
    print("Full: \(sensor.readFullSpectrum())")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}