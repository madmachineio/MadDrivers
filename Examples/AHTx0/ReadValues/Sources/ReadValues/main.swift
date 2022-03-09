// Read temperature and humidity every second.
import SwiftIO
import MadBoard
import AHTx0

let i2c = I2C(Id.I2C0)
let sensor = AHTx0(i2c)

while true {
    let temperature = sensor.readCelsius()
    let humidity = sensor.readHumidity()
    print("temperature: \(temperature)°C")
    print("humidity: \(humidity)%")
    sleep(ms: 1000)
}
