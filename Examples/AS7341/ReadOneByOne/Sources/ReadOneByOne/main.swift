// Read raw values of each channel one by one.
import SwiftIO
import MadBoard
import AS7341

let i2c = I2C(Id.I2C0)
let sensor = AS7341(i2c)

while true {
    print("f1: \(sensor.read415nm())")
    print("f2: \(sensor.read445nm())")
    print("f3: \(sensor.read480nm())")
    print("f4: \(sensor.read515nm())")
    print("f5: \(sensor.read555nm())")
    print("f6: \(sensor.read590nm())")
    print("f7: \(sensor.read630nm())")
    print("f8: \(sensor.read680nm())")
    print("clear: \(sensor.readClear())")
    print("NIR: \(sensor.readNIR())")

    sleep(ms: 1000)
}

