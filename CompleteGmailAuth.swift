import Foundation
import Network
import AppKit

// Complete Gmail authentication with callback server
print("🚀 Complete Gmail Authentication Test")
print(String(repeating: "=", count: 60))
print("📝 This will:")
print("   1. Start a callback server on localhost:8080")
print("   2. Generate a fresh authentication URL")
print("   3. Exchange the code for tokens")
print("   4. Save tokens for the JobTracker app")
print()

class GmailAuthComplete {
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let semaphore = DispatchSemaphore(value: 0)
    private var receivedCode: String?
    
    func startAuthentication() {
        // Start callback server first
        startCallbackServer()
        
        // Generate fresh auth URL
        let authURL = buildAuthURL()
        
        print("🌐 Open this URL in your browser:")
        print("📝 \(authURL.absoluteString)")
        print()
        print("📋 Instructions:")
        print("   1. Click the link above or copy it to your browser")
        print("   2. Sign in to your Google account")
        print("   3. Grant permission to read Gmail")
        print("   4. The callback server will automatically capture the code")
        print("   5. Tokens will be exchanged and saved automatically")
        print()
        
        // Try to open in browser automatically
        if NSWorkspace.shared.open(authURL) {
            print("✅ Browser opened automatically!")
        } else {
            print("ℹ️ Please manually open the URL above")
        }
        
        print("⏳ Waiting for authentication...")
        
        // Wait for callback
        if let code = waitForCallback() {
            print("✅ Got authorization code! Exchanging for tokens...")
            exchangeCodeForTokens(code)
        } else {
            print("❌ No authorization code received")
        }
    }
    
    private func startCallbackServer() {
        print("🚀 Starting callback server on port \(port)...")
        
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
            print("📝 Received OAuth callback")
            
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
                                
                                self.sendSuccessResponse(connection: connection)
                                self.semaphore.signal()
                                return
                            }
                        }
                    }
                }
            }
        }
        
        sendErrorResponse(connection: connection)
    }
    
    private func sendSuccessResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/html
        Content-Length: 400
        Connection: close
        
        <!DOCTYPE html>
        <html>
        <head>
            <title>Authentication Successful</title>
            <style>
                body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f8ff; }
                .success { color: #4CAF50; font-size: 28px; margin-bottom: 20px; }
                .info { color: #666; margin: 10px 0; }
                .code { background: #e8f5e8; padding: 15px; margin: 20px; border-radius: 5px; word-break: break-all; }
            </style>
        </head>
        <body>
            <div class="success">✅ Authentication Successful!</div>
            <div class="info">Your Gmail has been connected to JobTracker</div>
            <div class="info">You can now close this window and return to the app</div>
            <script>
                setTimeout(() => {
                    window.close();
                    if (!window.closed) {
                        document.body.innerHTML += '<div class="info">You can safely close this tab</div>';
                    }
                }, 3000);
            </script>
        </body>
        </html>
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
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
    
    private func waitForCallback() -> String? {
        let result = semaphore.wait(timeout: .now() + 120) // 2 minute timeout
        
        listener?.cancel()
        listener = nil
        
        if result == .timedOut {
            print("⏰ Timeout: No callback received within 2 minutes")
            return nil
        }
        
        return receivedCode
    }
    
    private func buildAuthURL() -> URL {
        let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
        let redirectURI = "http://localhost:8080/callback"
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.readonly"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func exchangeCodeForTokens(_ code: String) {
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token exchange failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Token exchange successful!")
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            print("🔑 Access Token: \(accessToken.prefix(30))...")
                            print("🔄 Refresh Token: \(refreshToken.prefix(30))...")
                            
                            // Save tokens
                            self.saveTokensToFile(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Test the token
                            self.testAccessToken(accessToken)
                            
                        } else {
                            print("❌ Failed to extract tokens from response")
                        }
                    }
                } else {
                    print("❌ Token exchange failed: \(httpResponse.statusCode)")
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 Error: \(json)")
                    }
                }
            }
        }.resume()
    }
    
    private func saveTokensToFile(accessToken: String, refreshToken: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tokensFileURL = documentsURL.appendingPathComponent("gmail_tokens.json")
        
        let tokens: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "saved_at": Date().timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: tokens, options: .prettyPrinted)
            try data.write(to: tokensFileURL)
            print("💾 Tokens saved to: \(tokensFileURL.path)")
        } catch {
            print("❌ Failed to save tokens: \(error)")
        }
    }
    
    private func testAccessToken(_ accessToken: String) {
        print("\n🔄 Testing access token...")
        
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
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
                        
                        if let emailAddress = json["emailAddress"] as? String {
                            print("🎉 Successfully connected to Gmail: \(emailAddress)")
                        }
                    }
                    
                    print("\n🎉🎉🎉 GMAIL AUTHENTICATION COMPLETE! 🎉🎉🎉")
                    print("🚀 Your JobTracker app is now ready to:")
                    print("   ✅ Read your Gmail emails")
                    print("   ✅ Categorize job applications")
                    print("   ✅ Create job entries automatically")
                    
                } else {
                    print("❌ Token test failed: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

// Start the complete authentication process
let auth = GmailAuthComplete()
auth.startAuthentication()

print(String(repeating: "=", count: 60))
print("⏳ Authentication process started...")
