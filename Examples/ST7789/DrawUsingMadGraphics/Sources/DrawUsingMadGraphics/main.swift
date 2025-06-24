// Use MadGraphics library to draw shapes and text on the screen.
import SwiftIO
import MadBoard
import ST7789
import MadGraphics


let bl = DigitalOut(Id.D2)
let rst = DigitalOut(Id.D12)
let dc = DigitalOut(Id.D13)
let cs = DigitalOut(Id.D5)
let spi = SPI(Id.SPI0, speed: 30_000_000)

let screen = ST7789(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl, rotation: .angle90)
var screenBuffer = [UInt16](repeating: 0, count: screen.width * screen.height)
var frameBuffer = [UInt32](repeating: 0, count: screen.width * screen.height)

let robotoFont = Font(path: "/lfs/Resources/Fonts/Roboto-Regular.ttf" , pointSize: 12, dpi: 220)

let rootLayer = Layer(width: screen.width, height: screen.height, backgroundColor: Pixel.yellow)
rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
    screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: data)
}
sleep(ms: 1000)

let rect = Layer(at: Point(x: 20, y: 20), width: 200, height: 200, backgroundColor: Pixel.orange)
rootLayer.append(rect)
rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
    screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: data)
}
sleep(ms: 1000)

let label = TextLayer(at: Point(x: 120, y: 120), anchorPoint: UnitPoint.center, string: "Hello world!", font: robotoFont, foregroundColor: Pixel.white)
rootLayer.append(label)
rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
    screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: data)
}
sleep(ms: 1000)


while true {
    sleep(ms: 1000)
}