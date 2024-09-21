// Set a timer every 10s. If time is up, the LED will be toggled. So the LED blinks every 10s.
import SwiftIO
import MadBoard
import DS3231

let i2c = I2C(Id.I2C0)
let sensor = DS3231(i2c)
let led = DigitalOut(Id.D0)
let interruptPin = DigitalIn(Id.D1, mode: .pullUp)

var value = false

// When the time is up, toggle the LED and change the value in order to clear the alarm.
interruptPin.setInterrupt(.falling) {
    led.toggle()
    value = true
}

// The alarm1 will be activated every 10s.
sensor.setTimer1(second: 10, mode: .second)

while true {
    sleep(ms: 10)

    // Clear the alarm. The alarm will continue to be activated when the time is up.
    if value {
        sensor.clearAlarm(1)
        printTime(sensor.readTime())
        sensor.setTimer1(second: 10, mode: .second)
        value = false
    }
}

func printTime(_ time: PCF8523.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)")
}