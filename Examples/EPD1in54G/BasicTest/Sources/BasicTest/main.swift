// Stream a four-color test pattern to the 1.54-inch e-Paper panel.
import SwiftIO
import MadBoard
import EPD1in54G

let spi = SPI(Id(rawValue: 0), speed: 4_000_000)
let cs = DigitalOut(Id(rawValue: 9))
let dc = DigitalOut(Id(rawValue: 10))
let rst = DigitalOut(Id(rawValue: 14))
let busy = DigitalIn(Id(rawValue: 15))
let pwr = DigitalOut(Id(rawValue: 2))

let epd = EPD1in54G(
    spi: spi,
    cs: cs,
    dc: dc,
    rst: rst,
    busy: busy,
    pwr: pwr,
    autoInitialize: false)

epd.initializeForFullUpdate()
epd.clearScreen(EPD1in54G.Color.white)
sleep(ms: 1000)

epd.initializeForFastUpdate()
epd.beginDisplayData()

var row = [UInt8](repeating: EPD1in54G.Color.white.packedValue,
                  count: EPD1in54G.bytesPerRow)

for y in 0..<EPD1in54G.height {
    for byteIndex in 0..<EPD1in54G.bytesPerRow {
        let x = byteIndex * 4
        let color: EPD1in54G.Color

        if y < 50 {
            color = .black
        } else if y < 100 {
            color = .white
        } else if y < 150 {
            color = .yellow
        } else {
            color = .red
        }

        if x >= 75 && x < 125 && y >= 75 && y < 125 {
            row[byteIndex] = EPD1in54G.Color.black.packedValue
        } else {
            row[byteIndex] = color.packedValue
        }
    }

    epd.writeDisplayData(row)
}

epd.refreshDisplay()
epd.sleep()

while true {
    sleep(ms: 1000)
}
