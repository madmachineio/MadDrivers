// Import the SwiftIO library to use the releted functionalities.
import SwiftIO
// Immport the MadBoard to use pin id.
import MadBoard
// Import it to read temperatures.
import MCP9808

// Initialize the i2c pin and use it to initialize the sensor.
let i2c = I2C(Id.I2C0)
let sensor = MCP9808(i2c)

// Read the temperature and print it every second
while true {
    print("Temperature: \(sensor.readCelsius()) C")
    sleep(ms: 1000)
}