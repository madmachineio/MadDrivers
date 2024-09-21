// Set a timer every 20s and blink the LED at this rate.
import SwiftIO
import MadBoard
import PCF8523

let i2c = I2C(Id.I2C0)
let rtc = PCF8523(i2c)
let led = DigitalOut(Id.BLUE)
let pin = DigitalIn(Id.D0, mode: .pullUp)

var value = false
// Enable a timer that will generate an interrupt every 20s.
rtc.enableTimer(countPeriod: .second, count: 20)

// Blink the LED every 20s.
pin.setInterrupt(.falling) {
    led.toggle()
    value = true
}

while true {
    sleep(ms: 10)

    // When the interrupt happens, print the current time.
    if value {
        printTime(rtc.readTime())
        value = false
    }
}

func printTime(_ time: PCF8523.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)")
}