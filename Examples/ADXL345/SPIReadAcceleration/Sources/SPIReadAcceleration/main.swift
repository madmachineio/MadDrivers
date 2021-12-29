import SwiftIO
import MadBoard
import ADXL345

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D13, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for the sensor.
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = ADXL345(spi)

while true {
    sleep(ms: 1000)
    let values = sensor.readXYZ()
    print(values)
}