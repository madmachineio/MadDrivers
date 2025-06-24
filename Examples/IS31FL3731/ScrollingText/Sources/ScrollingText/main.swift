// Display a scrolling text from right to left.
import SwiftIO
import MadBoard
import IS31FL3731
import MadGraphics

let i2c = I2C(Id.I2C0)
let screen = IS31FL3731(i2c)

var screenBuffer = [UInt8](repeating: 0, count: screen.width * screen.height)
var frameBuffer = [UInt32](repeating: 0, count: screen.width * screen.height)

let robotoFont = Font(path: "/lfs/Resources/Fonts/RobotoMono-VariableFont_wght.ttf" , pointSize: 12)

let rootLayer = Layer(width: screen.width, height: screen.height, backgroundColor: Pixel.black)
rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toGray) { dirty, data in
    screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: data)
}

let text = TextLayer(at: Point(x: 0, y: 0), string: "Hello", font: robotoFont, foregroundColor: Pixel.white)
rootLayer.append(text)

// It is decided by the width of your text.
let xmin = -24
// It is decided by the width of the LED matrix.
let xmax = 16

while true {
    // The text will scroll from right to left.
    for x in (xmin...xmax).reversed() {
        text.position = Point(x: x, y: 0)
        rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toGray) { dirty, data in
            screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: data)
        }
        sleep(ms: 100)
    }
}


extension Pixel {
    static func toGray(_ pixel: UInt32) -> UInt8 {
        let r = (pixel >> 16) & 0xFF
        let g = (pixel >> 8) & 0xFF
        let b = pixel & 0xFF
        // Use the luminosity method to convert RGB to grayscale.
        return UInt8(0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b))
    }
}