// Draw a red square on a white background on the screen.
import SwiftIO
import MadBoard
import ST7789

let spi = SPI(Id.SPI0, speed: 50_000_000)
let cs = DigitalOut(Id.D9)
let dc = DigitalOut(Id.D10)
let rst = DigitalOut(Id.D14)
let bl = DigitalOut(Id.D2)

let screen = ST7789(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl, rotation: .angle90)

let white: UInt16 = 0xFFFF
let red: UInt16 = 0xF800

screen.clearScreen(white)
sleep(ms: 1000)

for x in 60..<180 {
    for y in 60..<180 {
        screen.writePixel(x: x, y: y, color: red)
    }
}

while true {
    sleep(ms: 1000)
}