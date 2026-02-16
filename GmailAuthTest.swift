import Foundation

// Simple test class for Gmail authentication
class GmailAuthTester {
    static func runBasicTests() {
        print("🧪 Starting Gmail Authentication Tests...")
        print("=" * 50)
        
        // Test 1: Check OAuth URL generation
        testOAuthURL()
        
        // Test 2: Check token endpoint
        testTokenEndpoint()
        
        // Test 3: Check Gmail API endpoint
        testGmailAPIEndpoint()
        
        print("=" * 50)
        print("✅ Basic tests completed!")
    }
    
    private static func testOAuthURL() {
        print("\n🔗 Testing OAuth URL Generation...")
        
        let clientID = "99861683980-f85mnpsbo066o1c08hblu8oimn1o3h57.apps.googleusercontent.com"
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
        
        if let url = components.url {
            print("✅ OAuth URL generated successfully")
            print("📝 URL: \(url.absoluteString)")
        } else {
            print("❌ Failed to generate OAuth URL")
        }
    }
    
    private static func testTokenEndpoint() {
        print("\n🔄 Testing Token Endpoint...")
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            print("❌ Invalid token URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Test with invalid parameters to see if endpoint is reachable
        let parameters = [
            "client_id": "test",
            "client_secret": "test",
            "grant_type": "authorization_code",
            "code": "test"
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token endpoint error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Token endpoint reachable (Status: \(httpResponse.statusCode))")
                
                if httpResponse.statusCode == 400 {
                    print("✅ Expected 400 status for invalid parameters")
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📝 Response: \(json)")
                }
            }
        }.resume()
    }
    
    private static func testGmailAPIEndpoint() {
        print("\n📧 Testing Gmail API Endpoint...")
        
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
            print("❌ Invalid Gmail API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer invalid_token", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Gmail API error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Gmail API endpoint reachable (Status: \(httpResponse.statusCode))")
                
                if httpResponse.statusCode == 401 {
                    print("✅ Expected 401 status for invalid token")
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📝 Response: \(json)")
                }
            }
        }.resume()
    }
}

// Extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Usage: GmailAuthTester.runBasicTests()
