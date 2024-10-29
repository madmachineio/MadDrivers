import SwiftIO
import MadBoard
import BME680

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D0, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = BME680(spi)

while true {
    print("Temperature: \(getDoubleString(sensor.readTemperature()))")
    print("Humiture: \(getDoubleString(sensor.readHumidity()))")
    print("Pressure: \(getDoubleString(sensor.readPressure()))")
    print("Gas: \(getDoubleString(sensor.readGasResistance()))")
    sleep(ms: 2000)
}

func getDoubleString(_ num: Double) -> String {
    let int = Int(num)
    let frac = Int((num - Double(int)) * 100)
    return "\(int).\(frac)"
}