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
                print("Temperature: \(getFloatString(temp))C")
            }
            if let humi = try? sensor.readHumidity() {
                print("Humidity: \(getFloatString(humi))%")
            }
            
            sleep(ms: 1000)
        }
    }
}

func getFloatString(_ num: Float) -> String {
    let int = Int(num)
    let frac = Int((num - Float(int)) * 100)
    return "\(int).\(frac)"
}