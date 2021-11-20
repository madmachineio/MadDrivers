import SwiftIO
import MadBoard
import PCF8523

let i2c = I2C(Id.I2C1)
let rtc = PCF8523(i2c)
let led = DigitalOut(Id.BLUE)
let pin = DigitalIn(Id.D12, mode: .pullUp)

rtc.enable1SecondTimer()

// Blink the LED every second.
pin.setInterrupt(.falling) {
    led.toggle()
}

while true {
    sleep(ms: 3000)
}
