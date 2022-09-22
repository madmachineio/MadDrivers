//=== ADT7410.swift -------------------------------------------------------===//
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

/// The **ADT7410** is a temperature sensor communicating via an I2C interface.
///
/// The temperature is measured with a resolution of 0.0625°C or 0.0078°C with an accuracy of ±0.5°C. The sensor can monitor the temperature. Monitor if the temperature exceeds a critical temperature and monitor that the temperature is within a certain range.
public class ADT7410{
    
    private let i2c: I2C
    private let serialBusAddress: SerialBusAddress
    lazy private var configuration: Configuration = readConfig()
    
    
    /// Initialize a ADT7410.
    ///
    /// - Parameters:
    ///    - ic2: The I2C interface on the board.
    ///    - serialBusAddress: The serial bus address from the ADT7410 chip.
    public init(_ ic2: I2C,_ serialBusAddress: SerialBusAddress = .a_00){
        self.i2c = ic2
        self.serialBusAddress = serialBusAddress
    }
    
    /// Read the temperature.
    /// - Returns: Temperature of the sensor.
    public func readCelcius() -> Double{
        let operationMode = configuration.operationMode
        
        if(operationMode == .ONE_SHOT || operationMode == .SHUTDOWN){
            set0perationMode(.ONE_SHOT)
            sleep(ms: 240)
        }
        
        return Self.toTemp(configuration.resulution,read(.TEMP_MSB,2))
    }
    
    /// Read the status.
    /// - Returns: Status of the sensor.
    public func readStatus() -> Status{
        Status(read(.STATUS))
    }
    
    /// Read the temparture range.
    ///
    /// If the temperature falls below the min value or rises above the max value, the INT pin is triggered. Default temperature range is 10°C to 64°C.
    /// - Returns: Temperture range of the INT Pin.
    public func readIntTemperatureRange() -> (minTemp: Double,maxTemp: Double) {
        ( Self.toTemp(configuration.resulution, read(.SETPOINT_TEMP_LOW_MSB,2)),
          Self.toTemp(configuration.resulution, read(.SETPOINT_TEMP_HIGH_MSB,2)))
    }
    
    /// Read the critical temparture.
    ///
    /// If the temperature rises above the value, the CT pin is triggered. Default critical temparture is 147°C.
    /// - Returns: Critical temparture for the CT pin.
    public func readCTCriticalTemperature() -> Double{
        Self.toTemp(configuration.resulution,read(.SETPOINT_TEMP_CRIT_MSB,2))
    }
    
    /// Read the temperature hysteresis value for the THIGH, TLOW, and TCRIT temperature limits.
    ///
    /// The value is subtracted from the THIGH and TCRIT values and added to the TLOW value to implement hysteresis. Default temperature hyst is 5°C.
    /// - Returns: Temperature hysteresis value.
    public func readHyst() -> UInt8{
        read(.SETPOINT_TEMP_HYST)
    }
    
    /// Read the configuration.
    /// - Returns:Configuration of the ADT7410.
    public func readConfig() -> Configuration{
        Configuration(read(.CONFIG))
    }
    
    /// Read the manufacturer id and revision number.
    ///
    /// Read the 8-bit id Register. The manufacturer id in bit 3 to bit 7 and the silicon revision in bit 0 to bit 2.
    /// - Returns: Manufacturer id and revision number of the chip.
    public func readId() -> (manufacturerID: UInt8, revision: UInt8){
        let byte = read(.ID)
        return (byte >> 3, byte & 0b111)
    }
    
    /// Set the operation mode.
    /// - Parameter mode: Operation mode
    public func set0perationMode(_ mode: OperationMode){
        configuration.operationMode = mode
        write([configuration.getByte()], to: .CONFIG)
    }
    
    /// Set the number of faults.
    /// - Parameter numberOfFaults: Number of faults.
    public func setNumberOfFaults(_ numberOfFaults: NumberOfFaults) {
        configuration.numberOfFaults = numberOfFaults
        write([configuration.getByte()],to: .CONFIG)
    }
    
    /// Set the CT output polarity.
    /// - Parameter ctOutputPolarity: Output polarity of the CT pin.
    public func setCTOutputPolarity(_ ctOutputPolarity: CTOutputPolarity){
        configuration.ctOutputPolarity = ctOutputPolarity
        write([configuration.getByte()],to: .CONFIG)
    }
    
    /// Set the INT output polarity.
    /// - Parameter intOutputPolarity: Output polarity of the INT pin.
    public func setINTOutputPolarity(_ intOutputPolarity: INTOutputPolarity){
        configuration.intOutputPolarity = intOutputPolarity
        write([configuration.getByte()],to: .CONFIG)
    }
    
    /// Set the temperature detection mode.
    /// - Parameter temperatureDetectionMode: Temperature detection mode.
    public func setTemperatureDetectionMode(_ temperatureDetectionMode: TemperatureDetectionMode){
        configuration.temperatureDetectionMode = temperatureDetectionMode
        write([configuration.getByte()],to: .CONFIG)
    }
    
    /// Set the temparture range.
    ///
    /// If the temperature falls below the min value or rises above the max value, the INT pin is triggered. Default temperature range is 10°C to 64°C.
    /// - Parameters:
    ///   - minTemp: Lower limit of the temperature range.
    ///   - maxTemp: Upper limit of the temperature range.
    public func setIntTemperatureRange(min minTemp: Double, max maxTemp: Double ){
        write(Self.toData(configuration.resulution, minTemp), to: .SETPOINT_TEMP_LOW_MSB)
        write(Self.toData(configuration.resulution, maxTemp), to: .SETPOINT_TEMP_HIGH_MSB)
    }
    
    /// Set the critical temparture.
    ///
    /// If the temperature rises above the value, the CT pin is triggered. Default critical temparture is 147°C.
    /// - Parameter tempature: Critical temparture for the CT pin.
    public func setCTCriticalTemperature(tempature: Double){
        write(Self.toData(configuration.resulution,tempature), to: .SETPOINT_TEMP_CRIT_MSB)
    }
    
    /// Set the temperature hysteresis value for the THIGH, TLOW, and TCRIT temperature limits.
    ///
    /// The value is subtracted from the THIGH and TCRIT values and added to the TLOW value to implement hysteresis. allowed values are from 0°C-15°C and default temperature hyst is 5°C.
    /// - Parameter tempature: Temperature hysteresis value.
    public func setHyst(tempature: UInt8){
        write([tempature], to: .SETPOINT_TEMP_HYST)
    }
    
    /// Set the configuration.
    /// - Parameter configuration:
    public func setConfig(_ configuration: Configuration) {
        write([configuration.getByte()], to: .CONFIG)
        self.configuration = configuration
    }
    
    /// Reset the configuration to the default values.
    ///
    /// Will not reset the entire I2C bus.The ADT7410 does not respond to the I2C bus commands (do not acknowledge) during the default values upload for approximately 200 μs.
    public func reset(){
        write([], to: .RESET)
        wait(us: 200)
    }
}

extension ADT7410 {
    
    func read(_ registerAddresse: RegisterAddress) -> UInt8{
        read(registerAddresse,1)[0]
    }
    
    func read(_ registerAddresse: RegisterAddress,_ registerSize: Int) -> [UInt8]{
        var buffer: [UInt8] = [UInt8](repeating: 0, count: registerSize)
        i2c.writeRead(registerAddresse.rawValue, into: &buffer, address: serialBusAddress.rawValue)
        return buffer
    }
    
    func write(_ data: [UInt8],to registerAddresse: RegisterAddress) {
        i2c.write([registerAddresse.rawValue]+data, to: serialBusAddress.rawValue)
    }
    
    static func toTemp(_ resulution: ADT7410.Resulution, _ data: [UInt8]) -> Double{
        let dataInt16 = (Int16(data[0]) << 8) | Int16(data[1])
        let isPositiveTemp = dataInt16 >= 0
        
        switch(resulution, isPositiveTemp){
        case (.r_13Bit,true): return Double(dataInt16 >> 3) / 16
        case (.r_13Bit,false): return Double(dataInt16 >> 3 | 0b1 << 15) / 16
        case (.r_16Bit,_ ): return Double(dataInt16) / 128
        }
    }
    
    static func toData(_ resulution: ADT7410.Resulution, _ temp: Double) -> [UInt8]{
        let isPositiveTemp = temp >= 0
        var data:Int16 = 0
        
        switch(resulution, isPositiveTemp){
        case (.r_13Bit,true): data = Int16(temp * 16) << 3
        case (.r_13Bit,false): data = (Int16(temp * 16) << 3) | 0b1 << 15
        case (.r_16Bit,_): data = Int16(temp * 128.0)
        }
        
        let uIntData = UInt16(bitPattern: data)
        return [UInt8( uIntData >> 8), UInt8(uIntData & 0x00ff) ]
    }
    
    /// Serial bus address of the ADT7410
    ///
    /// Like all I2C-compatible devices, the ADT7410 has a 7-bit serial address. The five MSBs of this address for the ADT7410 are set to 10010. Pin A1 and Pin A0 set the two LSBs. These pins can be configured two ways, low and high, to give four different address options.
    public enum SerialBusAddress: UInt8{
        case a_00 = 0x48
        case a_01 = 0x49
        case a_10 = 0x4A
        case a_11 = 0x4B
    }
    
    enum RegisterAddress: UInt8{
        case TEMP_MSB               = 0x00
        case TEMP_LSB               = 0x01
        case STATUS                 = 0x02
        case CONFIG                 = 0x03
        case SETPOINT_TEMP_HIGH_MSB = 0x04
        case SETPOINT_TEMP_HIGH_LSB = 0x05
        case SETPOINT_TEMP_LOW_MSB  = 0x06
        case SETPOINT_TEMP_LOW_LSB  = 0x07
        case SETPOINT_TEMP_CRIT_MSB = 0x08
        case SETPOINT_TEMP_CRIT_TSB = 0x09
        case SETPOINT_TEMP_HYST     = 0x0A
        case ID                     = 0x0B
        case RESET                  = 0x2F
    }
    
    /// Describes the status of the sensor.
    ///
    /// Status of the overtemperaure and undertemperature interrupts. It also reflects the status of a temperature conversion operation.
    public struct Status{
        public let isTLowInterrupt: Bool
        public let isTHightInterrupt: Bool
        public let isTCritInterrupt: Bool
        public let isWriteTemperaure: Bool
        
        init(_ byte: UInt8){
            isTLowInterrupt = byte.isBitSet(4)
            isTHightInterrupt = byte.isBitSet(5)
            isTCritInterrupt = byte.isBitSet(6)
            isWriteTemperaure = byte.isBitSet(7)
        }
    }
}
