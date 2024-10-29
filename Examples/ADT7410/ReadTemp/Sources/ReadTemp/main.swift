import SwiftIO
import MadBoard
import ADT7410


let i2c = I2C(Id.I2C0)
let sensor = ADT7410(i2c)


while (true) {
    sleep(ms: 2000)
    sensor.setNumberOfFaults(.ONE)
    
    let temp = getDoubleString(sensor.readCelcius())
    print("Temperature is " + temp + "°C")
}

func getDoubleString(_ num: Double) -> String {
    let int = Int(num)
    let frac = Int((num - Double(int)) * 100)
    return "\(int).\(frac)"
}