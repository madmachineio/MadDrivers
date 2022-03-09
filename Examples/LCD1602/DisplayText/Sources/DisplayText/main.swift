// Display the phrase "Hello World!" on the LCD.
import SwiftIO
import MadBoard
import LCD1602

// Initialize the I2C0 and the lcd.
let i2c = I2C(Id.I2C0)
let lcd = LCD1602(i2c)

// Set the display area and print the message on the LCD.
lcd.write(x: 0, y: 0, "Hello World!")

while true {
    sleep(ms: 1000)
}