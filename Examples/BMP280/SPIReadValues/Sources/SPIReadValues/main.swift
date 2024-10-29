// Read the temperature, barometric pressure and altitude every 2s.
import SwiftIO
import BMP280
import MadBoard

// The cs pin is high so that the sensor would be in an inactive state.
let cs = DigitalOut(Id.D0, value: true)
// The cs pin will be controlled by SPI. The CPOL and CPHA should be true for
let spi = SPI(Id.SPI0, csPin: cs, CPOL: true, CPHA: true)
let sensor = BMP280(spi)

while true {
    let temp = sensor.readTemperature()
    let pressure = sensor.readPressure()
    // Set the current sea level pressure to get a accurate altitude.
    let altitude = sensor.readAltitude(1020)
    
    print("tmeperature: \(getDoubleString(temp))")
    print("pressure: \(getDoubleString(pressure))")
    print("altitude: \(getDoubleString(altitude))")

    sleep(ms: 2000)
}

func getDoubleString(_ num: Double) -> String {
    let int = Int(num)
    let frac = Int((num - Double(int)) * 100)
    return "\(int).\(frac)"
}