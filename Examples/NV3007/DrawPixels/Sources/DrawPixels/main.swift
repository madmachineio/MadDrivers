// Draw a red square on a white background on the screen.
import SwiftIO
import MadBoard
import NV3007

let spi = SPI(Id.SPI0, speed: 30_000_000)
let cs = DigitalOut(Id.D1)
let dc = DigitalOut(Id.D5)
let rst = DigitalOut(Id.D0)
let bl = DigitalOut(Id.D2)

let screen = NV3007(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl)

let white: UInt16 = 0xFFFF
let red: UInt16 = 0x00F8

screen.clearScreen(white)
sleep(ms: 1000)

for y in 50..<100 {
    for x in 100..<200 {
        screen.writePixel(x: x, y: y, color: red)
    }
}

while true {
    sleep(ms: 1000)
}