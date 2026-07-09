// Use MadGraphics library to draw shapes and text on the screen.
import SwiftIO
import MadBoard
//import AXS15231B
//import MadGraphics


let spi = SPI(Id.SPI0, speed: 5_000_000)//, CPOL: true, CPHA: true)
let sharedD2 = DigitalOut(Id.D28, value: true)
let cs = DigitalOut(Id.D1)
let dc = DigitalOut(Id.D5)
let rst = DigitalOut(Id.D0)
let screen = AXS15231B(
    spi: spi,
    cs: cs,
    dc: dc,
    rst: rst,
    bl: sharedD2,
    rotation: .angle0
)



let width = screen.width
let height = screen.height
print("Screen initialized with width: \(width), height: \(height)")

var sendBuffer = [UInt16](repeating: 0, count: width * height)
for i in 0..<sendBuffer.count {
    sendBuffer[i] = 0x0000
}
sleep(ms: 1000)

let originX = 151
let originY = 1

for y in 0..<5 {
    for x in 0..<8 {
        let index = y * 8 + x
        if x < 4 {
            sendBuffer[index] = 0x00F8
            screen.writePixel(x: originX + x, y: originY + y, color: sendBuffer[index])
        } else {
            sendBuffer[index] = 0x1F00
            screen.writePixel(x: originX + x, y: originY + y, color: sendBuffer[index])
        }
        print("final data at (\(x), \(y)) = \(sendBuffer[index])")
    }
}

sleep(ms: 5000)
print("write bitmap")
screen.writeBitmap(x: originX, y: originY, width: 8, height: 5, data: sendBuffer)


while true {
    sleep(ms: 1000)
}
