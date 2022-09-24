//=== Configuration.swift -------------------------------------------------------===//
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

import SwiftIO

public extension ADT7410 {
    
    /// Describes the configuration of the sensor.
    ///
    /// The sensor can be configured via a configuration register. The following functions are possible via the configuration register:
    /// - Switching between 13-bit and 16-bit resolution
    /// - Switching between normal operation and complete shutdown
    /// - Switching between comparator and interrupt event mode on the INT and CT pins
    /// - Setting the active polarity of the CT and INT pins
    /// - Setting the number of errors that enable CT and INT
    /// - Enabling the default one-shot mode and SPS mode
    struct Configuration: Equatable{
        
        /// The number of undertemperature/overtemperature faults that can occur before setting the INT and CT pins.
        public var numberOfFaults: NumberOfFaults = .ONE
        /// The active polarity of the CT pin.
        public var ctOutputPolarity: CTOutputPolarity = .ACTIVE_LOW
        /// The active polarity of the INT pin.
        public var intOutputPolarity: INTOutputPolarity = .ACTIVE_LOW
        /// Describes which reset behavior the CT and INT pins have.
        public var temperatureDetectionMode: TemperatureDetectionMode = .COMPARATOR_MODE
        /// The operation mode describes in which cycle the temperature is measured by the chip.
        public var operationMode: OperationMode = .CONTINUOS
        /// The sensor store the temperature in 13 bit or 16 bit resulution.
        public var resulution: Resulution = .r_13Bit
        
        /// Initialize default configuration of a ADT7410.
        public init(){}
        
        init(_ configByte: UInt8){
            setByte(configByte)
        }
        
        mutating func setByte(_ configByte: UInt8){
            numberOfFaults = .init(rawValue: configByte & 0b11)!
            ctOutputPolarity = .init(rawValue: configByte & 0b100)!
            intOutputPolarity = .init(rawValue: configByte & 0b1000)!
            temperatureDetectionMode = .init(rawValue: configByte & 0b10000)!
            operationMode = .init(rawValue: configByte & 0b1100000)!
            resulution = .init(rawValue: configByte & 0b10000000)!
        }
        
        func getByte() -> UInt8{
            return ( numberOfFaults.rawValue |
                     ctOutputPolarity.rawValue |
                     intOutputPolarity.rawValue |
                     temperatureDetectionMode.rawValue |
                     operationMode.rawValue |
                     resulution.rawValue )
        }
    }
    
    /// The number of undertemperature/overtemperature faults that can occur before setting the INT and CT pins. This helps to avoid false triggering due0b to temperature noise.
    enum NumberOfFaults: UInt8{
        case ONE = 0b0
        case TWO = 0b1
        case THREE = 0b10
        case FOUR = 0b11
    }
    
    /// The active polarity of the CT pin.
    enum CTOutputPolarity: UInt8{
        case ACTIVE_LOW = 0b0
        case ACTIVE_HIGH = 0b100
    }
    
    /// The active polarity of the INT pin.
    enum INTOutputPolarity: UInt8{
        case ACTIVE_LOW = 0b0
        case ACTIVE_HIGH = 0b1000
    }
    
    /// Describes which reset behavior the CT and INT pins have.
    enum TemperatureDetectionMode: UInt8{
        
        /// In comparator mode, the INT pin returns to its inactive state when the temperature falls below the THIGH - THYST limit or rises above the TLOW + THYST limit. When the ADT7410 is placed in shutdown mode, the INT state is not reset in comparator mode.
        case COMPARATOR_MODE = 0b0
        
        /// In interrupt mode, the INT pin becomes inactive only when the ADT7410 register is read, i.e., regardless of when the temperature has recovered and is back within the range.
        case INTERRUPT_MODE = 0b10000
    }
    
    /// The operation mode describes in which cycle the temperature is measured by the chip.
    enum OperationMode: UInt8{
        
        /// The ADT7410 performs an automatic conversion sequence. During this automatic conversion sequence, one conversion takes 240 ms,This means that as soon as one temperature conversion is completed, another temperature conversion begins.
        case CONTINUOS = 0b0
        
        /// When one-shot mode is enabled, the ADT7410 immediately completes a conversion and then goes into shutdown mode. The one-shot mode is useful when one of the circuit design priorities is to reduce power consumption. After writing to the operation mode bits, wait at least 240 ms before reading back the temperature from the temperature value register. This delay ensures that the ADT7410 has adequate time to power up and complete a conversion.
        case ONE_SHOT = 0b100000    /// Conversion time is typically 240 ms.
        
        /// The ADT7410 measures/update the temperature once every second.  This operational mode reduces the average current consumption.
        case SPS = 0b1000000
        
        /// The entire IC is shut down and no further conversions are initiated until the ADT7410 is taken out of shutdown mode.The conversion result from the last conversion prior to shutdown can still be read from the ADT7410 even when it is in shutdown mode. The ADT7410 typically takes 1 ms (with a 0.1 μF decoupling capacitor) to come out of shutdown mode.  When the part is taken out of shutdown mode, the internal clock is started and a conversion is initiated.
        case SHUTDOWN = 0b1100000
    }
    
    /// The sensor store the temperature in 13 bit or 16 bit resulution.
    enum Resulution: UInt8{
        
        /// Sign bit + 12 bits gives a temperature resolution of 0.0625°C.
        case r_13Bit = 0b0
        
        /// Sign bit + 15 bits gives a temperature resolution of 0.0078°C.
        case r_16Bit = 0b10000000
    }
}
