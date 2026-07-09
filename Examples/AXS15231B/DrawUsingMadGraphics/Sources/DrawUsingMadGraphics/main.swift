// Use MadGraphics library to draw shapes and text on the screen.
import SwiftIO
import MadBoard
//import AXS15231B
import MadGraphics


let sharedD2 = DigitalOut(Id.D28, value: true)
let spi = SPI(Id.SPI0, speed: 30_000_000)
let cs = DigitalOut(Id.D1)
let dc = DigitalOut(Id.D5)
let rst = DigitalOut(Id.D0)
let screen = AXS15231B(spi: spi, cs: cs, dc: dc, rst: rst, bl: sharedD2, rotation: .angle0)


let logicWidth = screen.height
let logicHeight = screen.width

var frameBuffer = [UInt32](repeating: 0, count: logicWidth * logicHeight)
var screenBuffer = [UInt16](repeating: 0, count: logicWidth * logicHeight)

var sendBuffer = [UInt16](repeating: 0, count: logicWidth * logicHeight)


print("Initialization done, start drawing...")
let robotoFont = Font(path: "/SD:/Resources/Fonts/IosevkaTermNerdFontMono-SemiBold.ttf" , pointSize: 16 * 6, dpi: 72)

// var lutTable = [UInt8](repeating: 0, count: 256)
// for i in 0...255 {
//     lutTable[i] = lut(UInt8(i), gamma: 1.8)
//     print("\(i): \(lutTable[i])")
// }


// let maskPattern = Mask(width: 2, height: 2)
// maskPattern[0] = UInt8(100)
// maskPattern[1] = UInt8(85)
// maskPattern[2] = UInt8(70)
// maskPattern[3] = UInt8(55)

sleep(ms: 100)
let seed = UInt32(0xFFFFFFFF & getClockCycle())


let rootLayer = Layer(width: logicWidth, height: logicHeight, backgroundColor: 0x060A06)
rootLayer.draw { canvas in
    // canvas.fillRectangle(at: Point(x: 0, y: 0), width: 140, height: canvas.height, data: 0x000000)
    // canvas.fillRectangle(at: Point(x: 140, y: 0), width: 140, height: canvas.height, data: 0x020403)
    // canvas.fillRectangle(at: Point(x: 280, y: 0), width: 140, height: canvas.height, data: 0x060A06)
    // canvas.fillRectangle(at: Point(x: 420, y: 0), width: 140, height: canvas.height, data: 0x080C08)
}

// rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
//     for y in 0..<dirty.height {
//         for x in 0..<dirty.width {
//             let newX = dirty.height - 1 - y
//             let newY = x
//             let index = newY * dirty.height + newX
//             sendBuffer[index] = data[y * dirty.width + x]
//         }
//     }

//     let transformedRect = Rect(Point(x: logicHeight - (dirty.y + dirty.height), y: dirty.x), width: dirty.height, height: dirty.width)
//     screen.writeBitmap(x: transformedRect.x, y: transformedRect.y, width: transformedRect.width, height: transformedRect.height, data: sendBuffer)
// }
// sleep(ms: 1000)



//var text = "14:14:" + String(Int(14))
var text = "02:13:" + String(Int(24))

//let label = TextLayer(at: Point(x: 560 / 2, y: 170 / 2), anchorPoint: UnitPoint.center, string: text, font: robotoFont, foregroundColor: 0x7CFF7A)
//let label = TextLayer(at: Point(x: 0, y: 0), anchorPoint: UnitPoint.topLeading, string: text, font: robotoFont, foregroundColor: 0x4FCF52)
//let label = TextLayer(at: Point(x: 560 / 2, y: 170 / 2), anchorPoint: UnitPoint.center, string: text, font: robotoFont, foregroundColor: 0x2F7A35)


let label = TextLayer(at: Point(x: 0, y: 170 / 2), anchorPoint: UnitPoint.leading, string: text, font: robotoFont, foregroundColor: 0x2EFF38)
rootLayer.append(label)

// gammaCorrect(to: label.mask, lut: lutTable)
// addScanLine(to: label.mask, linePattern: [100, 90, 96, 84])
// applyPattern(to: label.mask, pattern: maskPattern)

// rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
//     for y in 0..<dirty.height {
//         for x in 0..<dirty.width {
//             let newX = dirty.height - 1 - y
//             let newY = x
//             let index = newY * dirty.height + newX
//             sendBuffer[index] = data[y * dirty.width + x]
//         }
//     }

//     let transformedRect = Rect(Point(x: logicHeight - (dirty.y + dirty.height), y: dirty.x), width: dirty.height, height: dirty.width)
//     screen.writeBitmap(x: transformedRect.x, y: transformedRect.y, width: transformedRect.width, height: transformedRect.height, data: sendBuffer)
// }
// sleep(ms: 5000)



var start: UInt = 0
var stop1: UInt = 0
var stop2: UInt = 0


var previousSecond = Int(getSystemUptimeInMilliseconds() / 1000)

print("Start main loop...")

while true {
    start = getClockCycle()

    let currentSecond = Int(getSystemUptimeInMilliseconds() / 1000)
    if currentSecond != previousSecond && currentSecond < 60 {
        previousSecond = currentSecond
        label.string = "18:17:" + String(currentSecond % 60)
        // gammaCorrect(to: label.mask, lut: lutTable)
        // applyGlowCross5TapInPlace(to: label.mask)
        // addScanLine(to: label.mask, linePattern: [100, 84, 96, 78])
        // applyPattern(to: label.mask, pattern: maskPattern)
    }
    
    stop1 = getClockCycle()

    rootLayer.render(into: &frameBuffer, output: &screenBuffer, transform: Pixel.toRGB565LE) { dirty, data in
        // for y in 0..<dirty.height {
        //     for x in 0..<dirty.width {
        //         let newX = dirty.height - 1 - y
        //         let newY = x
        //         let index = newY * dirty.height + newX
        //         sendBuffer[index] = data[y * dirty.width + x]
        //     }
        // }

        // let transformedRect = Rect(Point(x: logicHeight - (dirty.y + dirty.height), y: dirty.x), width: dirty.height, height: dirty.width)
        // screen.writeBitmap(x: transformedRect.x, y: transformedRect.y, width: transformedRect.width, height: transformedRect.height, data: sendBuffer)

        // Rotate the dirty rect 90 degrees clockwise into portrait scan order.
        let transformedRect = Rect(
            Point(x: logicHeight - dirty.maxY, y: dirty.x),
            width: dirty.height,
            height: dirty.width
        )

        let transformedStride = transformedRect.width

        for sourceY in 0..<dirty.height {
            let sourceRowStart = sourceY * dirty.width
            let destinationX = dirty.height - 1 - sourceY

            for sourceX in 0..<dirty.width {
                let destinationY = sourceX
                let destinationIndex = destinationY * transformedStride + destinationX
                sendBuffer[destinationIndex] = data[sourceRowStart + sourceX]
            }
        }

        screen.writeBitmap(
            x: transformedRect.x,
            y: transformedRect.y,
            width: transformedRect.width,
            height: transformedRect.height,
            data: sendBuffer
        )
    }
    stop2 = getClockCycle()

    let rendering = Int(cyclesToNanoseconds(start: start, stop: stop1) / 1_000_000)
    let sending = Int(cyclesToNanoseconds(start: stop1, stop: stop2) / 1_000_000)

    if rendering > 0 || sending > 0 {
        print("Render: \(rendering) ms, Send: \(sending) ms")
    }
    sleep(ms: 25)
}


@inline(__always)
func packARGB(_ a: Int, _ r: Int, _ g: Int, _ b: Int) -> UInt32 {
    let A = UInt32(max(0, min(255, a)))
    let R = UInt32(max(0, min(255, r)))
    let G = UInt32(max(0, min(255, g)))
    let B = UInt32(max(0, min(255, b)))
    return (A << 24) | (R << 16) | (G << 8) | B
}

@inline(__always)
func unpackARGB(_ p: UInt32) -> (a: Int, r: Int, g: Int, b: Int) {
    (Int((p >> 24) & 0xFF),
     Int((p >> 16) & 0xFF),
     Int((p >>  8) & 0xFF),
     Int(p & 0xFF))
}

@inline(__always)
func hash2(_ x: Int, _ y: Int, _ seed: UInt32) -> UInt32 {
    var h = UInt32(bitPattern: Int32(x)) &* 374761393
    h &+= (UInt32(bitPattern: Int32(y)) &* 668265263)
    h &+= seed &* 362437
    h = (h ^ (h >> 13)) &* 1274126177
    return h ^ (h >> 16)
}


@inline(__always)
func noiseSigned(_ x: Int, _ y: Int, _ seed: UInt32, amp: Int) -> Int {
    let h = hash2(x, y, seed)
    let v = Int(h & 0xFF) - 128
    return (v * amp) / 128
}

@inline(__always)
func clamp255(_ v: Int) -> Int { max(0, min(255, v)) }





@inline(__always)
func erodeEdge(alpha: UInt8, x: Int, y: Int, seed: UInt32) -> UInt8 {
    // 只处理边缘，主笔画别动
    if alpha < 40 || alpha > 180 { return alpha }
    let n = Int(hash2(x, y, seed) & 0xFF) // 0..255
    // 让一小部分边缘像素消失/变弱（概率可调）
    if n < 35 { return 0 }          // ~14% 边缘缺口
    if n < 80 { return alpha / 2 }  // 再 ~18% 变弱
    return alpha
}





@inline(__always)
func lut(_ grey: UInt8, gamma: Float) -> UInt8 {
    // Gamma 2.2 校正
    let f = Float(grey) / 255.0
    let corrected = Float.pow(f, gamma)
    return UInt8(max(0, min(255, Int(corrected * 255.0 + 0.5))))
}

// func gammaCorrect(to mask: Mask, lut: [UInt8]) {
//     for i in 0..<mask.width * mask.height {
//         let a = mask[i]
//         mask[i] = lut[Int(a)]
//     }
// }


// func addScanLine(to mask: Mask, linePattern: [Int]) {
//     for y in 0..<mask.height {
//         let patternValue = linePattern[y % linePattern.count]
//         for x in 0..<mask.width {
//             let index = y * mask.width + x
//             let a = Int(mask[index])
//             let newA = a * patternValue / 100
//             mask[index] = UInt8(newA)
//         }
//     }
// }


// func applyPattern(to mask: Mask, pattern: Mask) {
//     for y in 0..<mask.height {
//         for x in 0..<mask.width {
//             let index = y * mask.width + x
//             let a = Int(mask[index])
//             let p = Int(pattern[(y % pattern.height) * pattern.width + (x % pattern.width)])
//             let newA = a * p / 100
//             mask[index] = UInt8(newA)
//         }
//     }
// }


@inline(__always)
private func clampToByte(_ v: UInt16) -> UInt8 {
    return v > 255 ? 255 : UInt8(v)
}

/// 对 8-bit 灰度缓冲做 glow（十字 5-tap + 阈值门控）
/// 就地版本：只传入一个 inout buf
///
/// - Parameters:
///   - buf: 灰度缓冲（0...255）
///   - width: 宽度
///   - height: 高度
///   - glowQ8: glow 强度（Q8 定点，0...255），如 28 ≈ 0.11
///   - threshold: 阈值，<= threshold 不做 glow（防止黑底发灰）
///
/// 算法：
/// blur = (4*C + L + R + U + D) / 8
/// out  = C + glow * blur
///
/// 边界像素保持原值不变。
// func applyGlowCross5TapInPlace(
//     to mask: Mask,
//     glowQ8: Int = 56,
//     t0: Int = 20,
//     t1: Int = 88,
// ) {
//     let width = mask.width
//     let height = mask.height
//     if width < 3 || height < 3 { return }

//     // 关键：做一份只读快照，避免 in-place 时邻域读到已更新值
//     var src = [UInt8](repeating: 0, count: width * height)
//     for i in 0..<(width * height) {
//         src[i] = mask[i]
//     }
//     let gateDen = t1 - t0

//     for y in 1..<(height - 1) {
//         let row = y * width
//         let rowUp = (y - 1) * width
//         let rowDown = (y + 1) * width

//         for x in 1..<(width - 1) {
//             let idx = row + x
//             let c = Int(src[idx])

//             // Soft gate gQ8: 0...256
//             let gQ8: Int
//             if c <= t0 {
//                 gQ8 = 0
//             } else if c >= t1 {
//                 gQ8 = 256
//             } else {
//                 gQ8 = ((c - t0) * 256) / gateDen
//             }

//             // gate=0 -> 不加 glow
//             if gQ8 == 0 {
//                 mask[idx] = UInt8(c)
//                 continue
//             }

//             let l = Int(src[idx - 1])
//             let r = Int(src[idx + 1])
//             let u = Int(src[rowUp + x])
//             let d = Int(src[rowDown + x])

//             // 5-tap cross kernel
//             let blur = ((c << 2) + l + r + u + d + 4) >> 3

//             // add = blur * glow * gate
//             // Q8 * Q8 => Q16，再 >>16
//             let add = (blur * glowQ8 * gQ8 + (1 << 15)) >> 16

//             mask[idx] = clampToByte(UInt16(c) + UInt16(add))
//         }
//     }
// }












@_extern(c, "powf")
func powf(_ : Float, _ : Float) -> Float

private extension Float {
    @_transparent
    static func pow(_ x: Float, _ y: Float) -> Float {
        guard x >= 0 else { return .nan }
        if x == 0 && y == 0 { return .nan }
        return powf(x, y)
    }
}



