import SwiftIO
import MadBoard
import ESP32ATClient

@main
public struct HttpGet {
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
            try esp.joinAP(ssid: "", password: "", timeout: 20000, autoConnect: true)
            print("ESP32 WiFi status: \(esp.wifiStatus)")

            let ipInfo = try esp.getStationIP()
            print(ipInfo)

        } catch {
            print("Error: \(error)")
        }

        while true {
            if esp.wifiStatus == .ready {
                do {
                    let ret = try esp.httpGet(url: "https://httpbin.org/get")
                    print(ret)
                } catch {
                    print("Http GET Error: \(error)")
                }
            } else {
                _ = try? esp.readLine(timeout: 1000)
                print("WiFi status: \(esp.wifiStatus)")
            }

            sleep(ms: 1000)
        }
    }
}
