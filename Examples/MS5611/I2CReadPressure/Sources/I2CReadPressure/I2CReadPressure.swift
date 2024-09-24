// Read pressure and temperature using I2C communication and print the values.

import SwiftIO
import MadBoard
import MS5611

@main
public struct I2CReadPressure {
    public static func main() {
        let i2c = I2C(Id.I2C0)
        let sensor = MS5611(i2c)
        
        while true {
            let (temperature, pressure) = sensor.read()

            print("Temperature: " + getFloatString(temperature))
            print("Pressure: " + getFloatString(pressure))
            print(" ")
            sleep(ms: 1000)
        }
    }
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}