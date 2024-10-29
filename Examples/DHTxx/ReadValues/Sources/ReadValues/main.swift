// Read temperature and humidity every 2 seconds.
import SwiftIO
import MadBoard
import DHTxx

let pin = DigitalInOut(Id.D0)
let sensor = DHTxx(pin)

while true {
    let values = sensor.read()
    if let values = values {
        print("Temperature: \(getFloatString(values.1))")
        print("Humidity: \(getFloatString(values.0))")
    }
    sleep(ms: 2000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}