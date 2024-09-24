import MAX6675
import SwiftIO
import MadBoard

print("Read tempature with Max6675 sensor.")

let csPin = DigitalOut(Id.D17)
let spi = SPI(Id.SPI0,csPin: csPin)
let max6675 = MAX6675(spi: spi)

while true {
    sleep(ms: 2000)
    if let temparture = max6675.readCelsius(){
        let string = getDoubleString(temparture)
        print("Temparture is \(string)°C")
    }else {
        print("Thermocouple input of pins T+ and T- is open.")
    }
}

func getDoubleString(_ num: Double) -> String {
    let int = Int(num)
    let frac = Int((num - Double(int)) * 100)
    return "\(int).\(frac)"
}