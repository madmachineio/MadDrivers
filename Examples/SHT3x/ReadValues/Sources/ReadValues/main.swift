// Read temperature and humidity every second and print the readings.
import SwiftIO
import MadBoard
import SHT3x

let i2c = I2C(Id.I2C0)
let sensor = SHT3x(i2c)

while true {
    print("Celcius: \(getFloatString(sensor.readCelsius()))")
    print("Humidity: \(getFloatString(sensor.readHumidity()))")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}