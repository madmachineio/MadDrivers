// Read all channels of the sensor consecutively. It ensures the data is concurrent.
// The sensor returns the amount of visible lights, clear and NIR (near IR) light.
import SwiftIO
import MadBoard
import AS7341

let i2c = I2C(Id.I2C0)
let sensor = AS7341(i2c)

while true {
    printChannels(sensor)
    sleep(ms: 1000)
}


func printChannels(_ sensor: AS7341) {
    let channels = sensor.readChannels()

    print("f1 = \(channels.f1)")
    print("f2 = \(channels.f2)")
    print("f3 = \(channels.f3)")
    print("f4 = \(channels.f4)")
    print("f5 = \(channels.f5)")
    print("f6 = \(channels.f6)")
    print("f7 = \(channels.f7)")
    print("f8 = \(channels.f8)")
    print("clear = \(channels.clear)")
    print("nir = \(channels.nir)")
}
