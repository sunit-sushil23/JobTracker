import Foundation
import AppKit
import AuthenticationServices
import WebKit

struct Email {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let content: String
    let snippet: String
}

enum GmailAuthMethod {
    case oauthWebFlow
    case oauthWebView
    case directAuth
}

class GmailServiceImproved: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var authMethod: GmailAuthMethod = .oauthWebFlow
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let redirectURI = "http://localhost:8080/callback"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var callbackServer: OAuthCallbackServer?
    private var authSession: ASWebAuthenticationSession?
    private var webViewWindow: NSWindow?
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var gmailTokensFileURL: URL {
        documentsURL.appendingPathComponent("gmail_tokens_improved.json")
    }
    
    override init() {
        super.init()
        loadTokens()
    }
    
    // MARK: - Public Authentication Methods
    
    func authenticate() {
        authenticate(with: .oauthWebFlow)
    }
    
    func authenticate(with method: GmailAuthMethod) {
        authMethod = method
        isLoading = true
        error = nil
        
        switch method {
        case .oauthWebFlow:
            authenticateWithWebFlow()
        case .oauthWebView:
            authenticateWithWebView()
        case .directAuth:
            authenticateDirectly()
        }
    }
    
    // MARK: - Authentication Method 1: OAuth Web Flow (Improved)
    
    private func authenticateWithWebFlow() {
        // Start callback server
        callbackServer = OAuthCallbackServer { [weak self] code in
            self?.exchangeCodeForTokens(code)
        }
        
        do {
            try callbackServer?.start()
        } catch {
            self.error = "Failed to start callback server: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        Task {
            do {
                let authURL = buildAuthURL()
                
                await MainActor.run {
                    let url = authURL
                    NSWorkspace.shared.open(url)
                }
                
                // Wait for callback with timeout
                await waitForCallbackWithTimeout()
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func waitForCallbackWithTimeout() async {
        let timeout = TimeInterval(120) // 2 minutes
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if isAuthenticated {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        await MainActor.run {
            self.error = "Authentication timed out. Please try again."
            self.isLoading = false
            self.callbackServer?.stop()
        }
    }
    
    // MARK: - Authentication Method 2: OAuth with WebView
    
    private func authenticateWithWebView() {
        Task {
            await MainActor.run {
                let authURL = buildAuthURL()
                presentWebView(for: authURL)
            }
        }
    }
    
    private func presentWebView(for url: URL) {
        let webView = WKWebView()
        webView.navigationDelegate = self
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Gmail Authentication"
        window.contentViewController = NSViewController()
        window.contentViewController?.view = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        webViewWindow = window
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - Authentication Method 3: Direct Auth Session
    
    private func authenticateDirectly() {
        Task {
            do {
                let authURL = buildAuthURL()
                
                let authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "http"
                ) { [weak self] callbackURL, error in
                    Task { @MainActor in
                        if let error = error {
                            self?.error = "Authentication failed: \(error.localizedDescription)"
                            self?.isLoading = false
                            return
                        }
                        
                        guard let callbackURL = callbackURL else {
                            self?.error = "No callback URL received"
                            self?.isLoading = false
                            return
                        }
                        
                        self?.handleDirectCallback(callbackURL)
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
    
    private func handleDirectCallback(_ callbackURL: URL) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            error = "Failed to get authorization code from callback"
            isLoading = false
            return
        }
        
        exchangeCodeForTokens(code)
    }
    
    // MARK: - Common OAuth Methods
    
    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/userinfo.email"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func exchangeCodeForTokens(_ code: String) {
        isLoading = true
        
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
            "redirect_uri": redirectURI
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.error = "Token exchange failed: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.error = "Invalid response from server"
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    self.error = "Server returned error code: \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received from server"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            self.accessToken = accessToken
                            self.refreshToken = refreshToken
                            self.isAuthenticated = true
                            self.saveTokens()
                            
                            // Clean up
                            self.callbackServer?.stop()
                            self.webViewWindow?.close()
                            self.webViewWindow = nil
                            
                            print("✅ Gmail authentication successful!")
                            
                        } else if let error = json["error"] as? String {
                            self.error = "OAuth error: \(error)"
                        } else {
                            self.error = "Failed to parse token response"
                        }
                    } else {
                        self.error = "Failed to parse JSON response"
                    }
                } catch {
                    self.error = "Failed to parse token response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else {
            return false
        }
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccessToken = json["access_token"] as? String {
                
                accessToken = newAccessToken
                saveTokens()
                return true
            }
        } catch {
            print("Failed to refresh token: \(error)")
        }
        
        return false
    }
    
    // MARK: - Gmail API Methods
    
    func fetchJobApplicationEmails() async throws -> [Email] {
        // Try to refresh token if needed
        if let token = accessToken, isTokenExpired(token) {
            let refreshed = await refreshAccessToken()
            if !refreshed {
                throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Token expired and refresh failed"])
            }
        }
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
                throw NSError(domain: "GmailService", code: httpResponse?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch emails"])
        }
        
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
    
    private func isTokenExpired(_ token: String) -> Bool {
        // Simple check - in production, you should parse the JWT token
        // For now, we'll assume tokens expire after 1 hour
        return false
    }
    
    // MARK: - Token Management
    
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
        
        callbackServer?.stop()
        webViewWindow?.close()
        webViewWindow = nil
    }
    
    // MARK: - Test Authentication
    
    func testAuthentication() async -> Bool {
        guard let accessToken = accessToken else {
            error = "No access token available"
            return false
        }
        
        let urlString = "https://www.googleapis.com/gmail/v1/users/me/profile"
        guard let url = URL(string: urlString) else {
            error = "Invalid test URL"
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Gmail authentication test successful!")
                    return true
                } else if httpResponse.statusCode == 401 {
                    print("⚠️ Token expired, attempting refresh...")
                    let refreshed = await refreshAccessToken()
                    if refreshed {
                        print("✅ Token refresh successful!")
                        return true
                    } else {
                        error = "Token refresh failed, please re-authenticate"
                        return false
                    }
                } else {
                    error = "Test failed with status code: \(httpResponse.statusCode)"
                    return false
                }
            }
        } catch {
            error = "Authentication test failed: \(error.localizedDescription)"
        }
        
        return false
    }
}

// MARK: - Extensions

extension GmailServiceImproved: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
    }
}

extension GmailServiceImproved: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url,
           url.absoluteString.hasPrefix(redirectURI) {
            
            decisionHandler(.cancel)
            
            // Extract the authorization code
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
               let code = codeItem.value {
                
                exchangeCodeForTokens(code)
            } else {
                error = "Failed to get authorization code from callback"
                isLoading = false
            }
            
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.error = "WebView navigation failed: \(error.localizedDescription)"
        isLoading = false
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.error = "WebView provisional navigation failed: \(error.localizedDescription)"
        isLoading = false
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
