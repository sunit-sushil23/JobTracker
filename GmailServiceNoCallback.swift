import Foundation
import AppKit
import AuthenticationServices

struct Email {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let content: String
    let snippet: String
}

class GmailServiceNoCallback: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var authSession: ASWebAuthenticationSession?
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var gmailTokensFileURL: URL {
        documentsURL.appendingPathComponent("gmail_tokens_no_callback.json")
    }
    
    override init() {
        super.init()
        loadTokens()
    }
    
    func authenticate() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Use a custom redirect URI that works with ASWebAuthenticationSession
                let authURL = buildAuthURL()
                
                let authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "com.googleusercontent.apps.99861683980-6hmorequ8glv2gr2cu7eu88q6lt1bdh4"
                ) { [weak self] callbackURL, error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.error = "Authentication failed: \(error.localizedDescription)"
                            self.isLoading = false
                            return
                        }
                        
                        guard let callbackURL = callbackURL else {
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
                if !success {
                    await MainActor.run {
                        self.error = "Failed to start authentication session"
                        self.isLoading = false
                    }
                }
                
            } catch {
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
            URLQueryItem(name: "redirect_uri", value: "http://localhost:8080/callback"),
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
            error = "Failed to extract authorization code"
            isLoading = false
            return
        }
        
        print("✅ Extracted authorization code: \(code.prefix(10))...")
        exchangeCodeForTokens(code)
    }
    
    private func exchangeCodeForTokens(_ code: String) {
        print("🔄 Exchanging code for tokens...")
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
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
            "redirect_uri": "http://localhost:8080/callback"
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
                        
                        if let error = json["error"] as? String {
                            if error == "invalid_client" {
                                self.error = "OAuth client not found. Please check Google Cloud Console setup."
                            } else if error == "redirect_uri_mismatch" {
                                self.error = "Redirect URI mismatch. Please add http://localhost:8080/callback to your OAuth client."
                            } else {
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
                            
                            self.saveTokens()
                            
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
    
    func fetchJobApplicationEmails() async throws -> [Email] {
        guard let accessToken = accessToken else {
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let query = "application OR applied OR interview OR job OR position OR resume OR cover letter"
        let urlString = "https://www.googleapis.com/gmail/v1/users/me/messages?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var emails: [Email] = []
        
        for message in messages.prefix(50) { // Limit to 50 most recent emails
            if let messageId = message["id"] as? String {
                do {
                    let email = try await fetchEmailDetails(messageId: messageId, accessToken: accessToken)
                    emails.append(email)
                } catch {
                    print("Failed to fetch email details: \(error)")
                }
            }
        }
        
        return emails.sorted { $0.date > $1.date }
    }
    
    private func fetchEmailDetails(messageId: String, accessToken: String) async throws -> Email {
        let urlString = "https://www.googleapis.com/gmail/v1/users/me/messages/\(messageId)?format=full"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to parse email"])
        }
        
        let snippet = json["snippet"] as? String ?? ""
        let internalDate = json["internalDate"] as? Int64 ?? 0
        let date = Date(timeIntervalSince1970: TimeInterval(internalDate) / 1000)
        
        var subject = ""
        var from = ""
        var content = ""
        
        if let payload = json["payload"] as? [String: Any] {
            // Extract headers
            if let headers = payload["headers"] as? [[String: Any]] {
                for header in headers {
                    if let name = header["name"] as? String,
                       let value = header["value"] as? String {
                        if name.lowercased() == "subject" {
                            subject = value
                        } else if name.lowercased() == "from" {
                            from = value
                        }
                    }
                }
            }
            
            // Extract content
            content = extractContent(from: payload)
        }
        
        return Email(
            id: messageId,
            subject: subject,
            from: from,
            date: date,
            content: content,
            snippet: snippet
        )
    }
    
    private func extractContent(from payload: [String: Any]) -> String {
        var content = ""
        
        if let parts = payload["parts"] as? [[String: Any]] {
            for part in parts {
                if let mimeType = part["mimeType"] as? String,
                   mimeType.contains("text/plain") {
                    if let bodyData = part["body"] as? [String: Any],
                       let data = bodyData["data"] as? String {
                        content += decodeBase64(data) + "\n"
                    }
                } else if part["parts"] != nil {
                    content += extractContent(from: part)
                }
            }
        } else if let bodyData = payload["body"] as? [String: Any],
                  let data = bodyData["data"] as? String {
            content = decodeBase64(data)
        }
        
        return content
    }
    
    private func decodeBase64(_ string: String) -> String {
        guard let data = Data(base64URLEncoded: string) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func saveTokens() {
        guard let accessToken = accessToken, let refreshToken = refreshToken else { return }
        
        let tokens: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "saved_at": Date().timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: tokens)
            try data.write(to: gmailTokensFileURL)
            print("✅ Tokens saved successfully")
        } catch {
            print("Failed to save tokens: \(error)")
        }
    }
    
    private func loadTokens() {
        do {
            let data = try Data(contentsOf: gmailTokensFileURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                accessToken = json["access_token"] as? String
                refreshToken = json["refresh_token"] as? String
                
                // Check if tokens are recent enough (less than 7 days)
                if let savedAt = json["saved_at"] as? TimeInterval {
                    let savedDate = Date(timeIntervalSince1970: savedAt)
                    let daysSinceSaved = Calendar.current.dateComponents([.day], from: savedDate, to: Date()).day ?? 0
                    
                    if daysSinceSaved < 7 && accessToken != nil {
                        isAuthenticated = true
                        print("✅ Loaded existing tokens")
                    } else {
                        print("⚠️ Tokens are old, requiring re-authentication")
                    }
                }
            }
        } catch {
            print("Failed to load tokens: \(error)")
        }
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        
        do {
            try FileManager.default.removeItem(at: gmailTokensFileURL)
            print("✅ Logged out successfully")
        } catch {
            print("Failed to remove tokens file: \(error)")
        }
    }
}

extension GmailServiceNoCallback: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Pad with '=' if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        
        self.init(base64Encoded: base64)
    }
}
