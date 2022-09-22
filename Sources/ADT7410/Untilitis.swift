//=== Untilitis.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Jan Anstipp
// Created: 16/09/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

extension Comparable{
    func inRange(_ min: Self,_ max: Self) -> Self{
        self < min ? min : (self > max) ? max : self
    }
}

extension Int16 {
    func toData() -> [UInt8]{
        let uInt16 = self.magnitude
        return [UInt8(uInt16 >> 8), UInt8(uInt16 & 0x00ff)]
    }
}

extension UInt8{
    func isBitSet(_ pos: Int) -> Bool{
        (self & (1 << pos)) != 0
    }
}
