// Read the acceleration and rotation values from the sensor using SPI.
import SwiftIO
import MadBoard
import BMI160

@main
public struct SPIReadMotion {

    public static func main() {
        let cs = DigitalOut(Id.D0, value: true)
        let spi = SPI(Id.SPI0)
        let sensor = BMI160(spi, csPin: cs)

        while true {
            let (aX, aY, aZ) = sensor.readAcceleration()
            let (rX, rY, rZ) = sensor.readRotation()

            print("Acceleration: \(getFloatString(aX)), \(getFloatString(aY)), \(getFloatString(aZ))")
            print("Rotation: \(getFloatString(rX)), \(getFloatString(rY)), \(getFloatString(rZ))")
            sleep(ms: 1000)
        }
    }
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}