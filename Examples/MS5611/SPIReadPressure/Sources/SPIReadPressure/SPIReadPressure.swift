// Read pressure and temperature using SPI communication and print the values.

import SwiftIO
import MadBoard
import MS5611

@main
public struct SPIReadPressure {
    public static func main() {
        let csPin = DigitalOut(Id.D0, value: true)
        let spi = SPI(Id.SPI0)
        let sensor = MS5611(spi, csPin: csPin)

        // Or
        // let csPin = DigitalOut(Id.D0, value: true)
        // let spi = SPI(Id.SPI0, csPin: csPin)
        // let sensor = MS5611(spi)
        
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