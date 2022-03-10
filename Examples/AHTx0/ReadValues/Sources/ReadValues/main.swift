// Read temperature and humidity every second.
import SwiftIO
import MadBoard
import AHTx0

let i2c = I2C(Id.I2C0)
let humiture = AHTx0(i2c)

while true {
    let temperature = humiture.readCelsius()
    let humidity = humiture.readHumidity()
    print("temperature: \(temperature)°C")
    print("humidity: \(humidity)%")
    sleep(ms: 1000)
}
