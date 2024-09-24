// Print the time info every 2s.
import SwiftIO
import MadBoard
import PCF8563

let i2c = I2C(Id.I2C0)
let rtc = PCF8563(i2c)

// If the RTC has stopped work due to power off, the time will set to current
// time. If not, the time will not be reset.
let current = PCF8563.Time(
    year: 2021, month: 11, day: 17, hour: 16,
    minute: 49, second: 51, dayOfWeek: 2)
rtc.setTime(current)

while true {
    // Read current time. It returns a optional value and you need to unwrap it.
    printTime(rtc.readTime())
    sleep(ms: 2000)
}

func printTime(_ time: PCF8563.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)")
}