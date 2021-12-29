import SwiftIO
import MadBoard
import BME680

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D13, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = BME680(spi)

while true {
    print("Temperature: \(sensor.readTemperature())")
    print("Humiture: \(sensor.readHumidity())")
    print("Pressure: \(sensor.readPressure())")
    print("Gas: \(sensor.readGasResistance())")
    sleep(ms: 2000)
}
