import SwiftIO
import MadBoard
import HCSR04

let trig = DigitalOut(Id.D12)
let echo = DigitalIn(Id.D13)
let sensor = HCSR04(trig: trig, echo: echo)

while true {
    let distance = sensor.measure()
    if let distance = distance {
        print("Distance: \(distance)m")  
    }
    sleep(ms: 1000)
}