// Check the capacitance change on 12 touch pads/pins of the sensor to see if any of them are touched.
// When you put your finger on a certain pin or move away your finger from it, 
// you'll see a message printed on serial monitor.

import SwiftIO
import MadBoard
import MPR121

@main
public struct CheckTouched {
    public static func main() {
        let i2c = I2C(Id.I2C0)
        let sensor = MPR121(i2c)

        var lastPinStatus = [Bool](repeating: false, count: 12)
        
        while true {
            for i in 0..<12 {
                let pinStatus = sensor.isTouched(pin: i)
                if pinStatus && !lastPinStatus[i] {
                    print("Pin \(i) is touched")
                    lastPinStatus[i] = true
                } else if !pinStatus && lastPinStatus[i] {
                    print("Pin \(i) is released")
                    lastPinStatus[i] = false
                }
            }

            sleep(ms: 10)
        }
    }
}
