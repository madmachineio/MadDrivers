//=== TSL2591.swift -------------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Jan Anstipp
// Created: 09/23/2022
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

/// The operation mode describes in which cycle the temperature is measured by the chip.
public enum OperationMode: UInt8{
    /// Performs an automatic conversion sequence. ``ConversionRate``  specifies the rate at which the temperature is measured.
    case SEQUENTIAL = 0b0
    /// The device shuts down when  the temperature conversion is completed. Shutdown mode conserves maximum power by turning off all of the device's circuits except the serial port, reducing power consumption to typically less than 0.5A.
    case ONESHOT = 0b1
}

/// Describes which reset behavior the ALT pin have.
public enum AlertMode: UInt8{
    /// In Comparator mode, the Alert pin is activated when the temperature equals or exceeds the T(HIGH) and remains active until the temperature falls below the T(LOW).
    case COMPARATOR = 0b0
    /// In Interrupt mode, the Alert pin is activated when the temperature exceeds T(HIGH) or goes below T(LOW) registers. The Alert pin is cleared when the host controller reads the temperature register.
    case INTERRUPT = 0b10
}

/// The active polarity of the alert pin.
public enum AlertOutputPolarity: UInt8{
    /// Alt Pin is set to HIGHT in active state.
    case LOW = 0b0
    /// Alt Pin is set to HIGHT in active state.
    case HIGH = 0b100
    
    var boolValue: Bool { self == .HIGH}
}

/// The number of undertemperature/overtemperature faults that can occur before setting the ALT pin. This helps to avoid false triggering due0b to temperature noise.
public enum NumberOfFaults: UInt8{
    case ONE = 0b0
    case TWO = 0b01000
    case THREE = 0b10000
    case FOUR = 0b11000
}

/// Data format of the tempt values. The sensor store the temperature in 12 bit or 13 bit resulution.
public enum DataFormat: UInt8{
    /// Sign bit + 11 bits gives a temperature resolution of 0.0625°C.
    case _12Bit = 0b0
    /// Sign bit + 12 bits gives a temperature resolution of 0.0625°C.
    case _13Bit = 0b10000
}

/// The conversion rate at which the sensor update the temperature. Sequential temperature measurement is only executed when ``OperationMode`` is set  to ``SEQUENTIAL``.
public enum ConversionRate : UInt8{
    /// Temperature is measured every 4 s
    case _0_25HZ = 0b0
    /// Temperature is measured every 1 s
    case _1HZ = 0b1000000
    /// Temperature is measured every 0.25 s
    case _4HZ = 0b10000000
    /// Temperature is measured every 0.125 s
    case _8HZ = 0b11000000
}

/// Serial bus address of the TMP102
///
/// Like all I2C-compatible devices, the ADT7410 has a 7-bit serial address. The five MSBs of this address for the ADT7410 are set to 10010. Pin A1 set the two LSBs.
public enum SerialBusAddress: UInt8{
    case x48 = 0x48
    case x49 = 0x49
    case x4A = 0x4A
    case x4B = 0x4B
}

enum RegisterAddress: UInt8{
    case TEMP = 0
    case CONFIG = 1
    case LOW_TEMP = 2
    case HIGH_TEMP = 3
}
