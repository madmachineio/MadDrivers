import SwiftIO
import MadBoard
import ESP32ATClient

@main
public struct Prepare {
    public static func main() {
        sleep(ms: 100)

        let rst = DigitalOut(Id.D24, value: true)
        let uart = UART(Id.UART1, baudRate: 115200)
        let esp = ESP32ATClient(uart: uart, rst: rst)

        do {
            // If reset failed, you might need to adjust the baudrate.
            try esp.reset()
            print("ESP32 status: \(esp.esp32Status)")

            try esp.restore()
            print("ESP32 restore status: \(esp.esp32Status)")

            let version = try esp.getVersion()
            print("ESP32 version info:\n\(version)")
        } catch {
            print("Error: \(error)")
        }

        while true {            
            if let heartBeat = try? esp.heartBeat() {
                print("ESP32 heart beat result: \(heartBeat)")
            } else {
                print("ESP32 heat beat failed!")
            }
            sleep(ms: 1000)
        }
    }
}
