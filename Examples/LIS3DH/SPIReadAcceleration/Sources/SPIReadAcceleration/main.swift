// Read accelerations on the x, y, z-axis every second.
import SwiftIO
import MadBoard
import LIS3DH

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D0, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for the sensor.
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = LIS3DH(spi)

while true {
    print("x: \(getFloatString(sensor.readX()))g")
    print("y: \(getFloatString(sensor.readY()))g")
    print("z: \(getFloatString(sensor.readZ()))g")
    sleep(ms: 1000) 
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}