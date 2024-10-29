// Communicate with the sensor using SPI protocol to measure magnetic field on
// x, y, z-axis and represent the values in microteslas.
import SwiftIO
import MadBoard
import MLX90393

let cs = DigitalOut(Id.D13)
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = MLX90393(spi)

while true {
    let (mX, mY, mZ) = sensor.readXYZ()

    print("x: \(getFloatString(mX))uT")
    print("y: \(getFloatString(mY))uT")
    print("z: \(getFloatString(mZ))uT")
    sleep(ms: 1000) 
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}

