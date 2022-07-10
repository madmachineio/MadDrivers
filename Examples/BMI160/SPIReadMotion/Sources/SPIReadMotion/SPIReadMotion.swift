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
            print("Acceleration: \(sensor.readAcceleration())")
            print("Rotation: \(sensor.readRotation())")
            sleep(ms: 1000)
        }
    }
}
