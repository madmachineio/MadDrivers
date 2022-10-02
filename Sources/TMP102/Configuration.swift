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

/// Configuration of the TMP102 chip
public struct Configuration{
    
    /// The operation mode describes in which cycle the temperature is measured by the chip.
    public var operationMode: OperationMode = .SEQUENTIAL
    /// Describes which reset behavior the ALT pin have.
    public var temperatureAlertMode: AlertMode = .COMPARATOR
    /// The active polarity of the ALT pin.
    public var alertOutputPolarity: AlertOutputPolarity = .LOW
    /// The number of undertemperature/overtemperature faults that can occur before setting the ALT  pin.
    public var numberOfFaults: NumberOfFaults = .ONE
    /// The sensor store the temperature in 12 bit or 13 bit resulution.
    public var dataFormat: DataFormat = ._12Bit
    /// Enter the rate at which the temperature is measured.
    public var conversionRate: ConversionRate = ._4HZ
    /// Lower limit of temperature monitoring.
    public var lowTemp: Double = 0
    /// Upper limit of temperature monitoring.
    public var hightTemp: Double = 0
    
    /// Initialize default configuration of a TMP102.
    public init(){}
    
    /// Initialize configuration of a TMP102..
    init(_ configByte: [UInt8], lowTemp: Double, hightTemp: Double){
        setConfigBytes(configByte)
        self.lowTemp = lowTemp
        self.hightTemp = hightTemp
    }
    
    mutating func setConfigBytes(_ configBytes: [UInt8]){
        operationMode = .init(rawValue: configBytes[0] & 0b1)!
        temperatureAlertMode = .init(rawValue: configBytes[0] & 0b10)!
        alertOutputPolarity = .init(rawValue: configBytes[0] & 0b100)!
        numberOfFaults = .init(rawValue: configBytes[0] & 0b11000)!
        dataFormat = .init(rawValue: configBytes[1] & 0b10000)!
        conversionRate = .init(rawValue: configBytes[1] & 0b11000000)!
    }
    
    func getConfigBytes() -> [UInt8]{
        [ operationMode.rawValue | temperatureAlertMode.rawValue | alertOutputPolarity.rawValue | numberOfFaults.rawValue ,
          dataFormat.rawValue | conversionRate.rawValue ]
    }
}
