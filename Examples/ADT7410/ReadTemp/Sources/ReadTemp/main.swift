import SwiftIO
import MadBoard
import ADT7410


let i2c = I2C(Id.I2C1)
let sensor = ADT7410(i2c)


while (true) {
    sleep(ms: 2000)
    sensor.setNumberOfFaults(.ONE)
    
    print("Tempature is \(sensor.readCelcius()) C")
}
