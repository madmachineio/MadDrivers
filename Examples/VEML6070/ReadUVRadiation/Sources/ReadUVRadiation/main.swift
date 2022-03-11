// Read UV light raw readings from the sensor and calculate the radiation level.
import SwiftIO
import MadBoard
import VEML6070

let i2c = I2C(Id.I2C0)
let sensor = VEML6070(i2c)

while true {
    let rawValue = sensor.readUVRaw()
    let uvLevel = sensor.getUVLevel(rawValue)
    print("UV raw value: \(rawValue), UV level: \(uvLevel)")
    sleep(ms: 1000)
}