// Read current time and print it every 3s.
import SwiftIO
import MadBoard
import PCF8523

let i2c = I2C(Id.I2C0)
let rtc = PCF8523(i2c)

// Set the time if the RTC has lost power. You will need to change the time
// to your current time.
let time = PCF8523.Time(
    year: 2021, month: 11, day: 20, hour: 10,
    minute: 45, second: 0, dayOfWeek: 5)
rtc.setTime(time)

// Read the current time and print it every 3s.
while true {
    sleep(ms: 3000)
    printTime(rtc.readTime())
}

func printTime(_ time: PCF8523.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)
}