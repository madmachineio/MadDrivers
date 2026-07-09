// Draw a red square on a white background on the screen.
import SwiftIO
import MadBoard
import AXS15231B

let spi = SPI(Id.SPI0, speed: 30_000_000, CPOL: false, CPHA: false)
let cs = DigitalOut(Id.D1)
let dc = DigitalOut(Id.D5)
let rst = DigitalOut(Id.D0)
let bl = DigitalOut(Id.D2)

let screen = AXS15231B(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl)//, width: 170, height: 560, rotation: .angle0)

let white: UInt16 = 0xFFFF
let red: UInt16 = 0x00F8

screen.clearScreen(white)
sleep(ms: 1000)
screen.clearScreen(0x00F8)
sleep(ms: 1000)
screen.clearScreen(0xE007)
sleep(ms: 1000)
screen.clearScreen(0x1F00)
sleep(ms: 1000)
screen.clearScreen(0x0000)
sleep(ms: 1000)

for y in 50..<100 {
    for x in 50..<150 {
        screen.writePixel(x: x, y: y, color: red)
    }
}

while true {
    sleep(ms: 1000)
}