import SwiftIO
import MadBoard
import TMP102

print("Start monitoring tempatur with a TMP102 sensor.")

let led = DigitalOut(Id.BLUE)
let i2c = I2C(Id.I2C1)
let sensor = TMP102(i2c)
let alertPin = DigitalIn(Id.D25)

var config = Configuration()
config.alertOutputPolarity = .HIGH
config.operationMode = .SEQUENTIAL
config.temperatureAlertMode = .COMPARATOR
config.hightTemp = 23
config.lowTemp = 20
sensor.setConfig(config)

alertPin.setInterrupt(.bothEdge, callback: ({ () in
    
    if(alertPin.read()){
        led.write(false)
        print("Warning: Hit critical Tempetur of \(config.hightTemp) C. Warning is reseted when the tempeature drops below \(config.lowTemp) C")
    }
    else {
        led.write(true)
        print("Info: Warning is reseted. Tempeature drops below \(config.lowTemp) C")
    }
}))

led.write(!sensor.isAlert())

while (true) {
    sleep(ms: 2000)
    print("Tempature is \(sensor.readCelcius()) C.")
}
