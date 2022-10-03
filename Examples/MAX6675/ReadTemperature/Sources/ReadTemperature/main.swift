import MAX6675
import SwiftIO
import MadBoard

print("Read tempature with Max6675 sensor.")

let csPin = DigitalOut(Id.D17)
let spi = SPI(Id.SPI1,csPin: csPin)
let max6675 = MAX6675(spi: spi)

while true {
    sleep(ms: 2000)
    if let temparture = max6675.readCelsius(){
        print("Temparture is \(temparture)°C")
    }else {
        print("Thermocouple input of pins T+ and T- is open.")
    }
}

