import SwiftIO
import MadBoard
import MCP4725

let i2c = I2C(Id.I2C1)
let sensor = MCP4725(i2c)
let pin = AnalogIn(Id.A0)

while true {
    for i in 0...4095 {
        sensor.setRawValue(i)
    }
    for i in (0...4095).reversed() {
        sensor.setRawValue(i)
    }
}