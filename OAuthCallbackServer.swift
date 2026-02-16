import Foundation
import Network

class OAuthCallbackServer {
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let onCodeReceived: (String) -> Void
    
    init(onCodeReceived: @escaping (String) -> Void) {
        self.onCodeReceived = onCodeReceived
    }
    
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .main)
        print("OAuth callback server started on http://localhost:\(port)")
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        print("OAuth callback server stopped")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveRequest(on: connection)
            case .failed(let error):
                print("Connection failed: \(error)")
            case .cancelled:
                print("Connection cancelled")
            default:
                break
            }
        }
    }
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (content, _, isComplete, error) in
            guard let self = self, let content = content, isComplete, error == nil else {
                print("Error receiving data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let requestString = String(data: content, encoding: .utf8) ?? ""
            self.parseRequest(requestString, connection: connection)
        }
    }
    
    private func parseRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        
        for line in lines {
            if line.hasPrefix("GET ") {
                let components = line.components(separatedBy: " ")
                if components.count > 1 {
                    let path = components[1].components(separatedBy: "?")
                    if path.count > 1 {
                        let queryParams = path[1].components(separatedBy: "&")
                        for param in queryParams {
                            if param.hasPrefix("code=") {
                                let code = param.replacingOccurrences(of: "code=", with: "")
                                onCodeReceived(code)
                                sendResponse(connection: connection)
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sendResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/html
        Content-Length: 200
        Connection: close
        
        <html>
        <head><title>Authentication Successful</title></head>
        <body>
        <h1>Authentication Successful!</h1>
        <p>You can now return to the JobTracker app.</p>
        <script>
        setTimeout(() => window.close(), 3000);
        </script>
        </body>
        </html>
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    print("Error sending response: \(error)")
                }
                connection.cancel()
            })
        }
    }
}
