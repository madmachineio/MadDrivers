// Use MadDisplay library to draw shapes and text on the screen.
import SwiftIO
import MadBoard
import ST7789
import MadDisplay

let spi = SPI(Id.SPI0, speed: 50_000_000)
let cs = DigitalOut(Id.D9)
let dc = DigitalOut(Id.D10)
let rst = DigitalOut(Id.D14)
let bl = DigitalOut(Id.D2)

let screen = ST7789(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl, rotation: .angle90)

let display = MadDisplay(screen: screen)
let group = Group()

// Draw a yellow background.
let palette = Palette()
palette.append(Color.white)
palette.append(Color.yellow)

let bitmap = Bitmap(width: 240, height: 240, bitCount: 1)

for x in 0..<240 {
    for y in 0..<240 {
        bitmap.setPixel(x:x, y:y, 1)
    }
}

let tile = Tile(bitmap: bitmap, palette: palette)
group.append(tile)
display.update(group)
sleep(ms: 1000)

// Draw an orange rectangle.
let rect = Rect(x: 20, y: 20, width: 200, height: 200, fill: Color.orange)
group.append(rect)
display.update(group)
sleep(ms: 1000)

// Display "Hello world!" on the screen.
let label = Label(x: 100, y: 100, text: "Hello world!", color: Color.white)
group.append(label)
display.update(group)

while true {
    sleep(ms: 1000)
}