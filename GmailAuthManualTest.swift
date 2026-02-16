import Foundation
import AppKit
import AuthenticationServices

// Manual test for Gmail authentication
class GmailAuthManualTest: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let redirectURI = "http://localhost:8080/callback"
    
    private var accessToken: String?
    private var refreshToken: String?
    
    func runManualTest() {
        print("🧪 Starting Manual Gmail Authentication Test...")
        print("=" * 50)
        
        // Test 1: Direct OAuth with ASWebAuthenticationSession
        testDirectAuth()
    }
    
    private func testDirectAuth() {
        print("\n🔄 Testing Direct OAuth Authentication...")
        
        isLoading = true
        
        Task {
            do {
                let authURL = buildAuthURL()
                print("📝 Auth URL: \(authURL)")
                
                let authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "http"
                ) { [weak self] callbackURL, error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ Authentication failed: \(error.localizedDescription)")
                            self.error = error.localizedDescription
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
                
                let success = await authSession.start()
                if success {
                    print("✅ Auth session started successfully")
                } else {
                    print("❌ Failed to start auth session")
                    await MainActor.run {
                        self.error = "Failed to start authentication session"
                        self.isLoading = false
                    }
                }
                
            } catch {
                print("❌ Authentication error: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
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
        
        print("📝 Token request prepared")
        
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
                    }
                    self.error = "Server returned error code: \(httpResponse.statusCode)"
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
                        print("✅ Token response received: \(json.keys)")
                        
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
                        print("📝 Profile: \(json)")
                    }
                } else {
                    print("❌ Token test failed with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

extension GmailAuthManualTest: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Usage:
// let tester = GmailAuthManualTest()
// tester.runManualTest()
