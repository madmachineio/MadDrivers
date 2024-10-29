// Read distance between the sensor and an object in meters every second.
import SwiftIO
import MadBoard
import HCSR04

let trig = DigitalOut(Id.D0)
let echo = DigitalIn(Id.D1)
let sensor = HCSR04(trig: trig, echo: echo)

while true {
    let distance = sensor.measure()
    if let distance = distance {
        print("Distance: \(getFloatString(distance))m")  
    }
    sleep(ms: 1000)
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}