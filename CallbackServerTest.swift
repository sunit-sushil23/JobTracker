import Foundation
import Network

// Simple callback server to capture OAuth authorization code
class CallbackServerTest {
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let semaphore = DispatchSemaphore(value: 0)
    private var receivedCode: String?
    
    func startCallbackServer() {
        print("🚀 Starting OAuth Callback Server...")
        print("📝 Listening on http://localhost:8080")
        print("📝 Ready to receive OAuth callback...")
        print()
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.allowFastOpen = true
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
            print("✅ Callback server started successfully!")
            
        } catch {
            print("❌ Failed to start callback server: \(error)")
            print("🔧 Make sure port 8080 is available")
            return
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveRequest(on: connection)
            case .failed(let error):
                print("❌ Connection failed: \(error)")
            case .cancelled:
                print("ℹ️ Connection cancelled")
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (content, _, isComplete, error) in
            guard let self = self, let content = content, isComplete, error == nil else {
                print("❌ Error receiving data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let requestString = String(data: content, encoding: .utf8) ?? ""
            print("📝 Received request:")
            print("📄 \(requestString)")
            
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
                                print("✅ Authorization code received: \(code.prefix(20))...")
                                self.receivedCode = code
                                
                                // Send success response
                                self.sendSuccessResponse(connection: connection)
                                
                                // Signal that we got the code
                                self.semaphore.signal()
                                return
                            }
                        }
                    }
                }
            }
        }
        
        // If no code found, send error response
        sendErrorResponse(connection: connection)
    }
    
    private func sendSuccessResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/html
        Content-Length: 300
        Connection: close
        
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Successful</title>
            <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                .success { color: #4CAF50; font-size: 24px; }
                .code { background: #f0f0f0; padding: 10px; margin: 20px; word-break: break-all; }
            </style>
        </head>
        <body>
            <h1 class="success">✅ Authentication Successful!</h1>
            <p>Your Gmail authentication has been completed successfully.</p>
            <p>You can now return to the JobTracker application.</p>
            <div class="code">Authorization Code: \(receivedCode ?? "Unknown")</div>
            <script>
                setTimeout(() => window.close(), 5000);
            </script>
        </body>
        </html>
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Error sending response: \(error)")
                }
                connection.cancel()
            })
        }
    }
    
    private func sendErrorResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 400 Bad Request
        Content-Type: text/html
        Content-Length: 200
        Connection: close
        
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body>
            <h1>❌ Authentication Error</h1>
            <p>No authorization code received. Please try again.</p>
        </body>
        </html>
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
                connection.cancel()
            })
        }
    }
    
    func waitForCallback() -> String? {
        print("⏳ Waiting for OAuth callback...")
        print("📝 Complete the authentication in your browser...")
        print("📝 The callback server will capture the authorization code automatically")
        print()
        
        // Wait for the callback (timeout after 2 minutes)
        let result = semaphore.wait(timeout: .now() + 120)
        
        listener?.cancel()
        listener = nil
        
        if result == .timedOut {
            print("⏰ Timeout: No callback received within 2 minutes")
            return nil
        }
        
        return receivedCode
    }
    
    func exchangeCodeForTokens(_ code: String) {
        print("🔄 Exchanging authorization code for tokens...")
        
        let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
        let clientSecret = "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"
        let redirectURI = "http://localhost:8080/callback"
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            print("❌ Invalid token URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        print("📝 Sending token exchange request...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token exchange failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Token response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Token exchange successful!")
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 Token response: \(json)")
                        
                        if let accessToken = json["access_token"] as? String {
                            print("🔑 Access Token: \(accessToken.prefix(20))...")
                            print("🎉 Gmail authentication is now complete!")
                            print("🚀 You can use this access token to fetch Gmail emails")
                            
                            // Test the token
                            self.testAccessToken(accessToken)
                        }
                    }
                } else {
                    print("❌ Token exchange failed with status: \(httpResponse.statusCode)")
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 Error response: \(json)")
                    }
                }
            }
        }.resume()
    }
    
    private func testAccessToken(_ accessToken: String) {
        print("\n🔄 Testing access token...")
        
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
            print("❌ Invalid test URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token test failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Access token works perfectly!")
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📧 Gmail Profile: \(json)")
                        
                        if let emailAddress = json["emailAddress"] as? String {
                            print("🎉 Successfully connected to Gmail: \(emailAddress)")
                        }
                    }
                    
                    print("\n🎉🎉🎉 GMAIL AUTHENTICATION SUCCESS! 🎉🎉🎉")
                    print("🚀 Your JobTracker app can now read Gmail emails!")
                    
                } else {
                    print("❌ Token test failed: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

// Main execution
print("🧪 OAuth Callback Server Test")
print("📝 This will start a server to capture the Google OAuth callback")
print()

let server = CallbackServerTest()
server.startCallbackServer()

// Wait for the callback
if let code = server.waitForCallback() {
    print("\n✅ Got authorization code! Exchanging for tokens...")
    server.exchangeCodeForTokens(code)
} else {
    print("\n❌ No authorization code received")
}

print("\n📋 Test completed!")
