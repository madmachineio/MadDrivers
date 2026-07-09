// Measure major operations of the 1.54-inch four-color e-Paper panel.
import SwiftIO
import MadBoard
import EPD1in54G

let spi = SPI(Id(rawValue: 0), speed: 4_000_000)
let cs = DigitalOut(Id(rawValue: 9))
let dc = DigitalOut(Id(rawValue: 10))
let rst = DigitalOut(Id(rawValue: 14))
let busy = DigitalIn(Id(rawValue: 15))
let pwr = DigitalOut(Id(rawValue: 2))

let commandSingal = DigitalOut(Id(rawValue: 0))
let dataSingal = DigitalOut(Id(rawValue: 1))

commandSingal.high()
dataSingal.high()

print("-------------------------------EPD1in54G Timing Test---------------------------------")
sleep(ms: 500)

let epd = EPD1in54G(
    spi: spi,
    cs: cs,
    dc: dc,
    rst: rst,
    busy: busy,
    pwr: pwr,
    autoInitialize: false)

@discardableResult
func measure(_ name: String, _ body: () -> Bool) -> Bool {
    print("[START] \(name)")
    let start = getSystemUptimeInMilliseconds()
    commandSingal.low()
    let ok = body()
    commandSingal.high()
    let stop = getSystemUptimeInMilliseconds()
    let ms = stop - start

    if ok {
        print("[DONE] \(name): \(ms) ms")
    } else {
        print("[TIMEOUT] \(name): \(ms) ms")
    }

    return ok
}

func streamSolid(_ color: EPD1in54G.Color) {
    let row = [UInt8](repeating: color.packedValue,
                      count: EPD1in54G.bytesPerRow)

    epd.beginDisplayData()

    for _ in 0..<EPD1in54G.height {
        epd.writeDisplayData(row)
    }
}

func streamBands() {
    var row = [UInt8](repeating: EPD1in54G.Color.white.packedValue,
                      count: EPD1in54G.bytesPerRow)

    epd.beginDisplayData()

    for y in 0..<EPD1in54G.height {
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

        row.withUnsafeMutableBufferPointer { buffer in
            for index in 0..<buffer.count {
                buffer[index] = color.packedValue
            }
        }

        epd.writeDisplayData(row)
    }
}

func measureStream(_ name: String, _ body: () -> Void) {
    print("[START] \(name)")
    let start = getSystemUptimeInMilliseconds()
    dataSingal.low()
    body()
    dataSingal.high()
    let stop = getSystemUptimeInMilliseconds()
    let ms = stop - start
    print("[DONE] \(name): \(ms) ms")
}

// measure("Full init") {
//     epd.initializeForFullUpdate(timeout: 30.0)
// }

// measureStream("Stream white image data") {
//     streamSolid(.white)
// }

// measure("Full refresh white") {
//     epd.refreshDisplay(timeout: 60.0)
// }

// measure("Power off and deep sleep") {
//     epd.sleep(timeout: 30.0)
// }

// sleep(ms: 2000)

measure("Fast init") {
    epd.initializeForFastUpdate(timeout: 30.0)
}

measureStream("Stream four-color bands") {
    streamBands()
}

measure("Fast refresh bands") {
    epd.refreshDisplay(timeout: 60.0)
}

measure("Final sleep") {
    epd.sleep(timeout: 30.0)
}

while true {
    sleep(ms: 1000)
}
