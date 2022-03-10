// Display a scrolling text from right to left.
import SwiftIO
import MadBoard
import IS31FL3731
import MadDisplay

let i2c = I2C(Id.I2C0)
let led = IS31FL3731(i2c)
let display = MadDisplay(screen: led)
let group = Group()

let text = Label(y: 4, text: "Hello", font: ASCII8())
group.append(text)

// It is decided by the width of your text.
let xmin = -24
// It is decided by the width of the LED matrix.
let xmax = 16

while true {
    // The text will scroll from right to left.
    for x in (xmin...xmax).reversed() {
        text.setX(x)
        display.update(group)
        sleep(ms: 100)
    }
}


