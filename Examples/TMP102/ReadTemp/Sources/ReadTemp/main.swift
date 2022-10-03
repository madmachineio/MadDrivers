import SwiftIO
import MadBoard
import TMP102

let i2c = I2C(Id.I2C1)
let sensor = TMP102(i2c)

print("Start read tempatur with aw TMP102 sensor.")

while (true) {
    sleep(ms: 2000)
    print("Tempature is \(sensor.readCelcius()) C.")
}
