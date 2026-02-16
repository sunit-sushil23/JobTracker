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

class GmailService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let redirectURI = "http://localhost:8080/callback"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var callbackServer: OAuthCallbackServer?
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var gmailTokensFileURL: URL {
        documentsURL.appendingPathComponent("gmail_tokens.json")
    }
    
    override init() {
        super.init()
        print("🔧 GmailService init - loading tokens...")
        loadTokens()
        
        // Auto-authenticate if tokens exist
        if accessToken != nil && refreshToken != nil {
            isAuthenticated = true
            print("✅ Auto-authenticated with existing tokens")
            print("📧 Access Token: \(accessToken?.prefix(20) ?? "nil")...")
        } else {
            print("❌ No tokens found - authentication required")
        }
    }
    
    func authenticate() {
        // Skip browser authentication - use existing tokens directly
        if accessToken != nil && refreshToken != nil {
            print("✅ Using existing tokens - no browser needed")
            isAuthenticated = true
            return
        }
        
        // If no tokens exist, show error instead of opening browser
        error = "No Gmail tokens found. Please ensure gmail_tokens.json exists in Documents folder."
        print("❌ No tokens available - cannot authenticate")
        return
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
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            error = "Failed to get authorization code"
            return
        }
        
        exchangeCodeForTokens(code)
    }
    
    private func exchangeCodeForTokens(_ code: String) {
        isLoading = true
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            error = "Invalid token URL"
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
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let accessToken = json["access_token"] as? String,
                       let refreshToken = json["refresh_token"] as? String {
                        
                        self.accessToken = accessToken
                        self.refreshToken = refreshToken
                        self.isAuthenticated = true
                        self.saveTokens()
                        
                        // Bring app to foreground after successful authentication
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } else {
                        self.error = "Failed to parse token response"
                    }
                } catch {
                    self.error = "Failed to parse token response: \(error.localizedDescription)"
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
        
        let tokens = [
            "access_token": accessToken,
            "refresh_token": refreshToken
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: tokens)
            try data.write(to: gmailTokensFileURL)
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
                isAuthenticated = accessToken != nil
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
        } catch {
            print("Failed to remove tokens file: \(error)")
        }
    }
}

extension GmailService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if canImport(AppKit)
        // Prefer the key window; fall back to main window; otherwise, create a temporary window
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
#else
        return ASPresentationAnchor()
#endif
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

