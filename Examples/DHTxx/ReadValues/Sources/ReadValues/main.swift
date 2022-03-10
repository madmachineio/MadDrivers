// Read temperature and humidity every 2 seconds.
import SwiftIO
import MadBoard
import DHTxx

let pin = DigitalInOut(Id.D0)
let sensor = DHTxx(pin)

while true {
    let values = sensor.read()
    if let values = values {
        print("Temperature: \(values.1)")
        print("Humidity: \(values.0)")
    }
    sleep(ms: 2000)
}