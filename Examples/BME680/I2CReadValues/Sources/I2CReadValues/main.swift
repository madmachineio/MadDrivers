import SwiftIO
import MadBoard
import BME680

let i2c = I2C(Id.I2C0)
let sensor = BME680(i2c)

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