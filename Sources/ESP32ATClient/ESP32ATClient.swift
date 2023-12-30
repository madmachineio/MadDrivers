import SwiftIO

public final class ESP32ATClient {

    static let prefix = "AT"
    static let responseOK = "OK"
    static let responseError = "ERROR"
    static let endMark = "\r\n"
    static let promptByte = UInt8(0x3E)

    let uart: UART
    let rst: DigitalOut

    var lock = Mutex()
    var urcMessages: [URCMessage] = []

    private var receivedBytes: [UInt8]
    private var lastByte = UInt8(0)

    public private(set) var esp32Status: ESP32Status = .initialization
    public private(set) var wifiStatus: WiFiStatus = .disconnected
    public private(set) var connectionStatus: ConnectionStatus = .closed

    lazy var readyCallback: URCCallback = { [unowned self] (str: String) -> Void in
        esp32Status = .ready
        wifiStatus = .disconnected
        connectionStatus = .closed
    }

    lazy var busyCallback: URCCallback = { [unowned self] (str: String) in
        sleep(ms: 10)
    }

    lazy var wifiConnectedCallback: URCCallback = { [unowned self] (str: String) in
        wifiStatus = .connected
        connectionStatus = .closed
    }

    lazy var wifiReadyCallback: URCCallback = { [unowned self] (str: String) in
        wifiStatus = .ready
        connectionStatus = .closed
    }

    lazy var wifiDisconnectedCallback: URCCallback = { [unowned self] (str: String) in
        wifiStatus = .disconnected
        connectionStatus = .closed
    }

    lazy var connectionOKCallback: URCCallback = { [unowned self] (str: String) in
        connectionStatus = .established
    }

    lazy var sendOKCallback: URCCallback = { [unowned self] (str: String) in
        connectionStatus = .sendOK
    }

    lazy var sendFailCallback: URCCallback = { [unowned self] (str: String) in
        connectionStatus = .error
    }

    lazy var connectionCloseCallback: URCCallback = { [unowned self] (str: String) in
        connectionStatus = .closed
    }

    public init(uart: UART, rst: DigitalOut) {
        self.uart = uart
        self.rst = rst

        receivedBytes = []
        receivedBytes.reserveCapacity(1024 * 16)

        self.urcMessages = [
            URCMessage(prefix: "ready", callback: readyCallback),
            URCMessage(prefix: "busy p...", callback: busyCallback),

            URCMessage(prefix: "WIFI CONNECTED", callback: wifiConnectedCallback),
            URCMessage(prefix: "WIFI GOT IP", callback: wifiReadyCallback),
            URCMessage(prefix: "WIFI DISCONNECT", callback: wifiDisconnectedCallback),

            URCMessage(prefix: "CONNECT", callback: connectionOKCallback),
            URCMessage(prefix: "SEND OK", callback: sendOKCallback),
            URCMessage(prefix: "SEND FAIL", callback: sendFailCallback),
            URCMessage(prefix: "CLOSED", callback: connectionCloseCallback),
        ]
    }

    private func readByte(timeout: Int) throws -> UInt8 {
        var value: UInt8 = 0

        let result = uart.read(into: &value, timeout: timeout)
        switch result {
            case .success(let count):
            if count == 1 {
                return value
            } else {
                throw ESP32ATClientError.responseTimeout
            }
            case .failure(let err):
            throw err
        }
    }

    private func writeString(_ str: String) throws {
        let result = uart.write(str, addNullTerminator: false)
        if case .failure(let err) = result {
            throw err
        }
    }

    @discardableResult
    public func readLine(timeout: Int = -1, removeNLCR: Bool = true) throws -> String {
        var receivedOneLine = false

        while true {
            let byte = try readByte(timeout: timeout)

            if byte == 0x0A && lastByte == 0x0D {
                receivedOneLine = true
            }
            receivedBytes.append(byte)
            lastByte = byte
            if receivedOneLine {
                break
            }
        }
        if removeNLCR {
            receivedBytes.removeLast()
            receivedBytes.removeLast()
        }
        receivedBytes.append(0)
        let line = String(cString: receivedBytes)
        receivedBytes.removeAll(keepingCapacity: true)
        if !line.isEmpty {
            for urc in urcMessages {
                if (line.hasPrefix(urc.prefix)) || (!urc.suffix.isEmpty && line.hasSuffix(urc.suffix)) {
                    urc.callback(line)
                    break
                }
            }
        }
        return line
    }

    public func waitPrompt(timeout: Int = 2000) throws {
        lock.lock()
        defer { lock.unlock() }

        var byte: UInt8 = 0
        while true {
            do {
                byte = try readByte(timeout: timeout)
            } catch {
                throw ESP32ATClientError.receivePromptFailed
            }

            if byte == ESP32ATClient.promptByte {
                break
            }
        }
    }

    public func executeRequesst(_ rst: ATRequest, timeout: Int = 5000) throws -> ATResponse {
        var response = ATResponse()

        lock.lock()
        defer { lock.unlock() }

        let rstString = try rst.parse()
        try writeString(rstString)
        while true {
            let line = try readLine(timeout: timeout)
            if !line.isEmpty {
                response.content.append(line)
                if line.hasPrefix(ESP32ATClient.responseOK) {
                    response.ok = true
                    break
                } else if line.hasPrefix(ESP32ATClient.responseError) {
                    break
                }
            }
        }
        return response
    }
}

extension ESP32ATClient {
    public func heartBeat() throws -> Bool {
        let request = ATRequest(ATCommand.execute(command: ""))
        return try executeRequesst(request).ok
    }

    public func softReset() throws -> Bool {
        let request = ATRequest(ATCommand.execute(command: "+RST"))
        return try executeRequesst(request).ok
    }

    public func setEcho(to enable: Bool) throws -> Bool {
        let command = enable ? "E1" : "E0"

        let request = ATRequest(ATCommand.execute(command: command))
        let response = try executeRequesst(request)

        return response.ok
    }

    public func reset() throws {
        rst.low()
        sleep(ms: 40)
        uart.clearBuffer()
        esp32Status = .initialization
        wifiStatus = .disconnected
        connectionStatus = .closed
        receivedBytes.removeAll(keepingCapacity: true)
        lastByte = 0
        rst.high()

        while esp32Status != .ready {
            do {
                try readLine(timeout: 2000)
            } catch ESP32ATClientError.responseTimeout {
                if esp32Status != .ready {
                    throw ESP32ATClientError.resetError
                }
            } catch {
                throw error
            }
        }
    }

    public func restore() throws {
        let request = ATRequest(ATCommand.execute(command: "+RESTORE"))
        let response = try executeRequesst(request)

        if response.ok {
            esp32Status = .initialization
            wifiStatus = .disconnected
            connectionStatus = .closed
            receivedBytes.removeAll(keepingCapacity: true)
            lastByte = 0

            while esp32Status != .ready {
                do {
                    try readLine(timeout: 2000)
                } catch ESP32ATClientError.responseTimeout {
                    if esp32Status != .ready {
                        throw ESP32ATClientError.resetError
                    }
                } catch {
                    throw error
                }
            }
            return
        }

        throw ESP32ATClientError.responseError
    }

    public func setBaudRate(to speed: Int = 115200, storage: Bool = false) throws -> Bool {
        let command = storage ? "+UART_DEF" : "+UART_CUR"
        let parameter = "\(String(speed)),8,1,0,0"

        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        let response = try executeRequesst(request)

        return response.ok
    }

    public func getVersion() throws -> String {
        let command = "+GMR"

        let request = ATRequest(ATCommand.execute(command: command))
        let response = try executeRequesst(request)

        if response.ok {
            let version = response.content.reduce("") { str, item in
                str + item + "\n"
            }
            return version
        }

        throw ESP32ATClientError.responseError
    }
}


extension ESP32ATClient {

    public func getWiFiMode() throws -> WiFiMode {
        let command = "+CWMODE"
        let request = ATRequest(ATCommand.query(command: command))
        var response = try executeRequesst(request)
        var mode = WiFiMode.none

        if response.ok {
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            if !response.content.isEmpty {
                var result = response.content[0]
                result.removeCommand()
                switch result {
                    case "1":
                    mode = .station
                    case "2":
                    mode = .softAP
                    case "3":
                    mode = .stationSoftAP
                    default:
                    mode = .none
                }
            }
        }
        
        return mode
    }

    public func setWiFiMode(_ newMode: WiFiMode, autoConnect: Bool = true) throws -> Bool {
        let command = "+CWMODE"
        let parameter = newMode.rawValue + (autoConnect ? ",1" : ",0")
        
        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        let response = try executeRequesst(request)

        if response.ok {
            return true
        }
        return false
    }

    public func joinAP(ssid: String? = nil, password: String = "", timeout: Int = 20000, autoConnect: Bool = true) throws {
        let command = "+CWJAP"
        let request: ATRequest

        if let ssid = ssid {
            let reConnect = autoConnect ? "1" : "0"
            let parameter = "\"" + ssid + "\",\"" + password + "\",,," + reConnect
            request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        } else {
            request = ATRequest(ATCommand.execute(command: command))
        }

        var response = try executeRequesst(request, timeout: timeout)

        if response.ok {
            return
        } else {
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            if response.content.count > 0 {
                response.content[0].removeCommand()
                switch response.content[0] {
                    case "1":
                    throw ESP32ATClientJoinWiFiError.timeout
                    case "2":
                    throw ESP32ATClientJoinWiFiError.passwordError
                    case "3":
                    throw ESP32ATClientJoinWiFiError.cannotFindAP
                    case "4":
                    throw ESP32ATClientJoinWiFiError.connectFailed
                    default:
                    throw ESP32ATClientJoinWiFiError.unknownError
                }
            }
        }
    }

    public func leaveAP() throws -> Bool {
        let command = "+CWQAP"
        let request = ATRequest(ATCommand.execute(command: command))

        let response = try executeRequesst(request)
        return response.ok
    }

    public func getStationIP() throws -> [String] {
        let command = "+CIPSTA"
        let request = ATRequest(ATCommand.query(command: command))

        var response = try executeRequesst(request)

        if response.ok {
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            for i in 0..<response.content.count {
                response.content[i].removeCommand()
            }
            return response.content
        }

        throw ESP32ATClientError.responseError
    }

    public func setWebServer(to enable: Bool) throws -> Bool {
        let command = "+WEBSERVER"
        let parameter = (enable ? "1" : "0") + ",80" + ",60"

        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        let response = try executeRequesst(request)

        return response.ok
    }
}


extension ESP32ATClient {
    public func getHttpHead() throws -> String {
        let command = "+HTTPCHEAD"
        let request = ATRequest(ATCommand.query(command: command))

        var response = try executeRequesst(request)
        var string = ""

        if response.ok {
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            for var item in response.content {
                if let firstComma = item.firstIndex(of: ",") {
                    item.removeSubrange(item.startIndex...firstComma)
                    string += item
                }
            }
            return string
        }

        throw ESP32ATClientError.responseError
    }

    public func httpGet(url: String, headers: [String], timeout: Int = 5000) throws -> String {
        let command = "+HTTPCLIENT"
        var parameter = "2,0,\"" + url + "\",,,"

        if url.hasPrefix("https") {
            parameter += "2"
        } else if url.hasPrefix("http") {
            parameter += "1"
        } else {
            throw ESP32ATClientError.requestError
        }

        if headers.count > 0 {
            for item in headers {
                parameter += ",\"" + item + "\""
            }
        }

        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        var response = try executeRequesst(request, timeout: timeout)

        if response.ok {
            var string = ""
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            for var item in response.content {
                if let firstComma = item.firstIndex(of: ",") {
                    item.removeSubrange(item.startIndex...firstComma)
                    string += item
                }
            }
            return string
        }

        throw ESP32ATClientError.responseError
    }

    public func httpGet(url: String, timeout: Int = 5000) throws -> String {
        let command = "+HTTPCGET"
        let parameter = "\"" + url + "\",,," + String(timeout)

        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        var response = try executeRequesst(request, timeout: timeout)

        var string = ""
        if response.ok {
            response.content.removeAll { str in
                !str.hasPrefix(command)
            }
            for var item in response.content {
                if let firstComma = item.firstIndex(of: ",") {
                    item.removeSubrange(item.startIndex...firstComma)
                    string += item
                }
            }
            return string
        }

        throw ESP32ATClientError.responseError
    }

    public func httpPost(url: String, data: String = "\r\n", headers: [String] = [], timeout: Int = 5000) throws -> String {
        let command = "+HTTPCPOST"
        var parameter = "\"" + url + "\"," + String(data.utf8.count)

        if headers.count > 0 {
            parameter += "," + String(headers.count)
            for item in headers {
                parameter += ",\"" + item + "\"" 
            }
        }

        let request = ATRequest(ATCommand.setup(command: command, parameter: parameter))
        let sendResponse = try executeRequesst(request, timeout: timeout)

        if sendResponse.ok {
            try waitPrompt(timeout: timeout)
            connectionStatus = .closed

            try writeString(data)

            var receiveResponse = ATResponse()
            while connectionStatus != .sendOK {
                receiveResponse.content.append(try readLine(timeout: timeout))
            }

            receiveResponse.ok = true
            var string = ""

            receiveResponse.content.removeAll { str in
                !str.hasPrefix(command)
            }
            for var item in receiveResponse.content {
                if let firstComma = item.firstIndex(of: ",") {
                    item.removeSubrange(item.startIndex...firstComma)
                    string += item
                }
            }
            return string
        }

        throw ESP32ATClientError.responseError
    }
}

public extension ESP32ATClient {
    enum ESP32Status {
        case initialization
        case ready
    }

    enum WiFiStatus {
        case disconnected
        case connected
        case ready
    }

    enum ConnectionStatus {
        case closed
        case established
        case ready
        case sendOK
        case error
    }

    enum WiFiMode: String {
        case none = "0"
        case station = "1"
        case softAP = "2"
        case stationSoftAP = "3"
    }
}