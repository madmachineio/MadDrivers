// Read accelerations on x, y, z-axis per second and print them out.
import SwiftIO
import MadBoard
import ADXL345

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D0, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for the sensor.
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let accelerometer = ADXL345(spi)

while true {
    sleep(ms: 1000)
    let values = accelerometer.readXYZ()
    print("x: \(getFloatString(values.x)), y: \(getFloatString(values.y)), z: \(getFloatString(values.z))")
}


func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}