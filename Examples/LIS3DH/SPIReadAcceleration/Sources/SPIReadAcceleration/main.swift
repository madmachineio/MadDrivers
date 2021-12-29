import SwiftIO
import MadBoard
import LIS3DH

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D13, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for the sensor.
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = LIS3DH(spi)

while true {
    print("x: \(sensor.readX())g")
    print("y: \(sensor.readY())g")
    print("z: \(sensor.readZ())g")
    sleep(ms: 1000)
}