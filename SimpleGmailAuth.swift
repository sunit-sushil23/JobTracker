import Foundation
import AppKit
import AuthenticationServices

// Simple Gmail authentication using native macOS ASWebAuthenticationSession
class SimpleGmailAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    
    private var authSession: ASWebAuthenticationSession?
    private let semaphore = DispatchSemaphore(value: 0)
    private var authResult: Result<String, Error>?
    
    func authenticate() {
        print("🔐 Simple Gmail Authentication")
        print(String(repeating: "=", count: 50))
        print("📝 Using native macOS authentication")
        print("📝 This will open a secure authentication window")
        print()
        
        // Build the auth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "http://localhost:8080/callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.readonly"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components.url else {
            print("❌ Failed to build auth URL")
            return
        }
        
        print("🌐 Opening secure authentication window...")
        
        // Create ASWebAuthenticationSession
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: nil // Let macOS handle it
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                self.authResult = .failure(error)
            } else if let callbackURL = callbackURL {
                self.authResult = .success(callbackURL.absoluteString)
            } else {
                self.authResult = .failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No callback received"]))
            }
            
            self.semaphore.signal()
        }
        
        authSession?.presentationContextProvider = self
        
        // Start the authentication session
        Task {
            let success = await authSession?.start() ?? false
            
            await MainActor.run {
                if !success {
                    print("❌ Failed to start authentication session")
                    self.authResult = .failure(NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start auth session"]))
                    self.semaphore.signal()
                } else {
                    print("✅ Authentication session started")
                    print("📝 A secure window should appear...")
                    print("📝 Please complete the authentication in that window")
                }
            }
        }
        
        // Wait for authentication to complete
        semaphore.wait()
        
        // Handle the result
        switch authResult {
        case .success(let callbackURL):
            print("✅ Authentication successful!")
            print("📝 Callback URL: \(callbackURL)")
            
            // Extract the authorization code
            if let code = extractCodeFromCallback(callbackURL) {
                print("🔄 Exchanging code for tokens...")
                exchangeCodeForTokens(code)
            } else {
                print("❌ Failed to extract authorization code")
            }
            
        case .failure(let error):
            print("❌ Authentication failed: \(error.localizedDescription)")
        case .none:
            print("❌ No authentication result")
        }
    }
    
    private func extractCodeFromCallback(_ callbackURL: String) -> String? {
        guard let components = URLComponents(string: callbackURL),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            return nil
        }
        return code
    }
    
    private func exchangeCodeForTokens(_ code: String) {
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
        
        let tokenSemaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { tokenSemaphore.signal() }
            
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
        
        tokenSemaphore.wait()
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
        
        let testSemaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { testSemaphore.signal() }
            
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
                    print("🚀 Your JobTracker app is now ready!")
                    print("📱 The app will automatically load these tokens on startup")
                    
                } else {
                    print("❌ Token test failed: \(httpResponse.statusCode)")
                }
            }
        }.resume()
        
        testSemaphore.wait()
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

// Main execution
print("🚀 Starting Simple Gmail Authentication...")

let auth = SimpleGmailAuth()
auth.authenticate()

print(String(repeating: "=", count: 50))
print("📋 Authentication completed!")
