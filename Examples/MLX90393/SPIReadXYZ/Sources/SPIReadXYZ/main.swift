// Communicate with the sensor using SPI protocol to measure magnetic field on
// x, y, z-axis and represent the values in microteslas.
import SwiftIO
import MadBoard
import MLX90393

let cs = DigitalOut(Id.D13)
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = MLX90393(spi)

while true {
    print("Magnetic field: \(sensor.readXYZ())uT")
    sleep(ms: 1000)
}

