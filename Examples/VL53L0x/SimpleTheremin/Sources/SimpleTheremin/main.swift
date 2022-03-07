// As you move your hand closer (farther away) from the sensor, the sound from
// the buzzer becomes lower (higher).
import SwiftIO
import MadBoard
import VL53L0x

let i2c = I2C(Id.I2C1)
let sensor = VL53L0x(i2c)
let buzzer = PWMOut(Id.PWM5A)

while true {
    // The value is around 50-1200.
    let value = sensor.readRange()
    if let value = value {
        buzzer.set(frequency: value * 2, dutycycle: 0.5)
    }

    sleep(ms: 5)
}
