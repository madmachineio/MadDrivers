// Read air quality and get eCo2 and TVOC values.
import SwiftIO
import MadBoard
import SGP30

let i2c = I2C(Id.I2C0)
let sensor = SGP30(i2c)

// Set the current temperature and humidity for humidity compensation.
sensor.setRelativeHumidity(celcius: 20.4, humidity: 47.7) 

// Set the known baseline to calibrate the sensor. 
// When you use the sensor for the first time, please put it in a clean environment
// for about 12h to get the baseline of eCO2 and TVOC. 
// Then use the values to set sensor's baseline to calibrate it.
// sensor.setBaseline(eCO2: 37325, TVOC: 36918)

while true {
    // For the first 15s, the readins are always 400 for eCO2 and 0 for TVOC.
    let readings = sensor.readIAQ()
    print("eCO2: \(readings.eCO2) ppm, TVOC: \(readings.TVOC) ppb")
    sleep(ms: 1000)
}