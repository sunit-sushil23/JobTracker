import Foundation
import AppKit
import AuthenticationServices

// Real Gmail authentication test that opens browser
class RealGmailAuthTest: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let redirectURI = "http://localhost:8080/callback"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var authSession: ASWebAuthenticationSession?
    
    func runRealAuthenticationTest() {
        print("🚀 Starting Real Gmail Authentication Test...")
        print("=" * 60)
        
        print("📝 This will open your browser for real Google authentication")
        print("📝 You'll need to:")
        print("   1. Sign in to your Google account")
        print("   2. Grant permission to read Gmail")
        print("   3. The app will receive the callback automatically")
        print()
        
        print("🔧 Configuration:")
        print("   Client ID: \(clientID)")
        print("   Redirect URI: \(redirectURI)")
        print()
        
        print("🚀 Starting authentication...")
        authenticate()
    }
    
    func authenticate() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let authURL = buildAuthURL()
                print("📝 Opening URL: \(authURL)")
                
                let authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: nil // Use default scheme
                ) { [weak self] callbackURL, error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Authentication failed: \(error.localizedDescription)")
                            self.error = "Authentication failed: \(error.localizedDescription)"
                            self.isLoading = false
                            return
                        }
                        
                        guard let callbackURL = callbackURL else {
                            print("❌ No callback URL received")
                            self.error = "No callback URL received"
                            self.isLoading = false
                            return
                        }
                        
                        print("✅ Received callback: \(callbackURL)")
                        self.handleCallback(callbackURL)
                    }
                }
                
                authSession.presentationContextProvider = self
                self.authSession = authSession
                
                let success = await authSession.start()
                if success {
                    print("✅ Authentication session started")
                } else {
                    print("❌ Failed to start authentication session")
                    await MainActor.run {
                        self.error = "Failed to start authentication session"
                        self.isLoading = false
                    }
                }
                
            } catch {
                print("❌ Authentication error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = "Authentication error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func buildAuthURL() -> URL {
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
    
    private func handleCallback(_ callbackURL: URL) {
        print("🔄 Handling OAuth callback...")
        
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            print("❌ Failed to extract authorization code")
            error = "Failed to get authorization code from callback"
            isLoading = false
            return
        }
        
        print("✅ Extracted authorization code: \(code.prefix(10))...")
        exchangeCodeForTokens(code)
    }
    
    private func exchangeCodeForTokens(_ code: String) {
        print("🔄 Exchanging code for tokens...")
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            print("❌ Invalid token URL")
            error = "Invalid token URL"
            isLoading = false
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Token exchange failed: \(error.localizedDescription)")
                    self.error = "Token exchange failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response")
                    self.error = "Invalid response from server"
                    self.isLoading = false
                    return
                }
                
                print("📝 Token response status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ Server returned error: \(httpResponse.statusCode)")
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 Error response: \(json)")
                        
                        if let error = json["error"] as? String {
                            switch error {
                            case "invalid_client":
                                print("❌ Client ID/Secret issue")
                                self.error = "OAuth client credentials are invalid"
                            case "invalid_grant":
                                print("❌ Authorization code issue")
                                self.error = "Authorization code is invalid or expired"
                            case "redirect_uri_mismatch":
                                print("❌ Redirect URI mismatch")
                                self.error = "Redirect URI does not match Google Cloud Console"
                            default:
                                print("❌ Other OAuth error: \(error)")
                                self.error = "OAuth error: \(error)"
                            }
                        }
                    }
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    self.error = "No data received from server"
                    self.isLoading = false
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ Token response received!")
                        
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            self.accessToken = accessToken
                            self.refreshToken = refreshToken
                            self.isAuthenticated = true
                            self.isLoading = false
                            
                            print("✅ Authentication successful!")
                            print("🔑 Access token: \(accessToken.prefix(20))...")
                            print("🔄 Refresh token: \(refreshToken.prefix(20))...")
                            
                            // Test the token
                            self.testToken()
                            
                        } else {
                            print("❌ Failed to parse tokens from response")
                            self.error = "Failed to parse token response"
                            self.isLoading = false
                        }
                    } else {
                        print("❌ Failed to parse JSON response")
                        self.error = "Failed to parse JSON response"
                        self.isLoading = false
                    }
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    self.error = "Failed to parse token response: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func testToken() {
        print("🔄 Testing access token...")
        
        guard let accessToken = accessToken else {
            print("❌ No access token to test")
            return
        }
        
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
                    print("✅ Token test successful!")
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 Gmail Profile: \(json)")
                        
                        if let emailAddress = json["emailAddress"] as? String {
                            print("📧 Connected to Gmail: \(emailAddress)")
                        }
                        
                        if let historyId = json["historyId"] as? String {
                            print("📊 History ID: \(historyId)")
                        }
                    }
                    
                    print("\n🎉 Gmail authentication is working perfectly!")
                    print("🚀 You can now use the JobTracker app to process your Gmail!")
                    
                } else {
                    print("❌ Token test failed with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Main test execution
print("🧪 Real Gmail Authentication Test")
print("📝 This will test actual Gmail authentication with your browser")
print()

let tester = RealGmailAuthTest()
tester.runRealAuthenticationTest()

print()
print("📋 Instructions:")
print("1. A browser window will open for Google authentication")
print("2. Sign in and grant permission")
print("3. Return to this terminal to see the results")
print()
print("⏳ Waiting for authentication...")
