import SwiftIO
import MadBoard
import PCF8523

let i2c = I2C(Id.I2C1)
let rtc = PCF8523(i2c)
let led = DigitalOut(Id.BLUE)
let pin = DigitalIn(Id.D12, mode: .pullUp)

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
        print(rtc.readCurrent())
        value = false
    }
}
