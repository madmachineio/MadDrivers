// Read temperature and humidity every second.
import SwiftIO
import MadBoard
import AHTx0

let i2c = I2C(Id.I2C0)
let humiture = AHTx0(i2c)

while true {
    let temperature = getFloatString(humiture.readCelsius())
    let humidity = getFloatString(humiture.readHumidity())
    print("temperature: " + temperature + "°C")
    print("humidity: " + humidity + "%")
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}