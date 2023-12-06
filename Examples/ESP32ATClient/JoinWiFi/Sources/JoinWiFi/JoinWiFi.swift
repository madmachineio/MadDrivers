import SwiftIO
import MadBoard
import ESP32ATClient

@main
public struct JoinWiFi {
    public static func main() {
        sleep(ms: 100)

        let rst = DigitalOut(Id.D24, value: true)
        let uart = UART(Id.UART1, baudRate: 115200)
        let esp = ESP32ATClient(uart: uart, rst: rst)

        do {
            // If reset failed, you might need to adjust the baudrate.
            try esp.reset()
            print("ESP32 status: \(esp.esp32Status)")

            // Only in 'Station' or 'Station+SoftAP' mode can a connection to an AP be established.
            let wifiMode = try esp.getWiFiMode()
            print("ESP32 WiFi mode: \(wifiMode)")

            // Fill the SSID and password below.
            _ = try esp.joinAP(ssid: "", password: "")
            print("ESP32 WiFi status: \(esp.wifiStatus)")

            let ipInfo = try esp.getStationIP()
            print(ipInfo)

        } catch {
            print("Error: \(error)")
        }

        while true {            
            sleep(ms: 1000)
        }
    }
}
