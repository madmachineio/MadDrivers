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
        print("Distance: \(distance)m")  
    }
    sleep(ms: 1000)
}