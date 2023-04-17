// Read temperature and relative humidity every second.
import SwiftIO
import MadBoard
import HTU21D

@main
public struct ReadHumiture {
    public static func main() {
        let i2c = I2C(Id.I2C0)
        let sensor = HTU21D(i2c)

        while true {
            if let temp = try? sensor.readTemperature() {
                print("Temperature: \(temp)C")
            }
            if let humi = try? sensor.readHumidity() {
                print("Humidity: \(humi)%")
            }
            
            sleep(ms: 1000)
        }
    }
}
