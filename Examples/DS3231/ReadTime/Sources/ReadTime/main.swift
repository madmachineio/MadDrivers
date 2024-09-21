// Read current time and print it every 2s.
import SwiftIO
import MadBoard
import DS3231

let i2c = I2C(Id.I2C0)
let sensor = DS3231(i2c)

// If the RTC has stopped work due to power off, you need to reset the time. 
// If not, the time will not be reset. 
// Of course, you need to change the time below to your time.
let current = DS3231.Time(
    year: 2021, month: 11, day: 12, hour: 16,
    minute: 37, second: 42, dayOfWeek: 5)
sensor.setTime(current)


while true {
    // Read current time. It returns a optional value and you need to unwrap it.
    printTime(sensor.readTime())
    sleep(ms: 2000)
}

func printTime(_ time: PCF8523.Time) {
    print("MM/DD/YYYY: \(time.month)/\(time.day)/\(time.year)")
    print("Time: \(time.hour):\(time.minute):\(time.second)")
}