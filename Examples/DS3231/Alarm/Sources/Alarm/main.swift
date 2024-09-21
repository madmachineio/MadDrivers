// Set an alarm at 20s of each minute, such as 1m20s, 2m29s, 3m20s...
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

// The alarm1 will be activated when the second matches, like 1m20s, 2m20s...
sensor.setAlarm1(second: 20, mode: .second)

while true {
    sleep(ms: 10)

    // Clear the alarm. The alarm will continue to be activated when the time is up.
    if value {
        sensor.clearAlarm(1)
        printTime(sensor.readTime())
        value = false
    }
}

func printTime(_ time: PCF8523.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)")
}