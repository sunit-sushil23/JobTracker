import Foundation

// Exchange the authorization code for access tokens
print("🔄 Exchanging Authorization Code for Tokens")
print(String(repeating: "=", count: 50))

// Your authorization code from the callback
let authorizationCode = "4/0AfrIepAHsVxAcpMM8GS-TW-XDJSb9qtyfkFGwsWPdSNS11Z6VrtbM6y1Ge8QCaZFtr2X8Q"

let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
let clientSecret = "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"
let redirectURI = "http://localhost:8080/callback"

print("📝 Authorization Code: \(authorizationCode.prefix(30))...")
print("📝 Client ID: \(clientID)")
print("📝 Redirect URI: \(redirectURI)")
print()

guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
    print("❌ Invalid token URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

let parameters = [
    "client_id": clientID,
    "client_secret": clientSecret,
    "code": authorizationCode,
    "grant_type": "authorization_code",
    "redirect_uri": redirectURI
]

let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
request.httpBody = body.data(using: .utf8)

print("🔄 Sending token exchange request...")

let semaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Token exchange failed: \(error.localizedDescription)")
        semaphore.signal()
        return
    }
    
    if let httpResponse = response as? HTTPURLResponse {
        print("📊 Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            print("✅ Token exchange successful!")
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📝 Token Response: \(json)")
                
                if let accessToken = json["access_token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {
                    
                    print("\n🎉 AUTHENTICATION SUCCESS! 🎉")
                    print("🔑 Access Token: \(accessToken.prefix(30))...")
                    print("🔄 Refresh Token: \(refreshToken.prefix(30))...")
                    
                    // Save tokens to file for the app to use
                    saveTokensToFile(accessToken: accessToken, refreshToken: refreshToken)
                    
                    // Test the access token
                    testAccessToken(accessToken)
                    
                } else {
                    print("❌ Failed to extract tokens from response")
                }
            }
        } else {
            print("❌ Token exchange failed with status: \(httpResponse.statusCode)")
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📝 Error Response: \(json)")
                
                if let error = json["error"] as? String {
                    print("🔧 Error Details: \(error)")
                    if let description = json["error_description"] as? String {
                        print("📝 Description: \(description)")
                    }
                }
            }
        }
    }
    
    semaphore.signal()
}.resume()

semaphore.wait()

func saveTokensToFile(accessToken: String, refreshToken: String) {
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
        print("📱 The JobTracker app can now use these tokens!")
    } catch {
        print("❌ Failed to save tokens: \(error)")
    }
}

func testAccessToken(_ accessToken: String) {
    print("\n🔄 Testing Access Token...")
    
    guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
        print("❌ Invalid test URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let testSemaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Token test failed: \(error.localizedDescription)")
            testSemaphore.signal()
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                print("✅ Access Token Works Perfectly!")
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📧 Gmail Profile: \(json)")
                    
                    if let emailAddress = json["emailAddress"] as? String {
                        print("🎉 Successfully Connected to Gmail: \(emailAddress)")
                    }
                    
                    if let historyId = json["historyId"] as? String {
                        print("📊 History ID: \(historyId)")
                    }
                }
                
                print("\n🚀🚀🚀 GMAIL INTEGRATION IS READY! 🚀🚀🚀")
                print("📱 You can now run the JobTracker app and it will:")
                print("   ✅ Authenticate automatically using saved tokens")
                print("   ✅ Fetch your job application emails")
                print("   ✅ Categorize them using AI")
                print("   ✅ Create job entries in your Kanban board")
                
            } else {
                print("❌ Token test failed: \(httpResponse.statusCode)")
            }
        }
        
        testSemaphore.signal()
    }.resume()
    
    testSemaphore.wait()
}

print(String(repeating: "=", count: 50))
print("📋 Next Steps:")
print("1. ✅ Tokens will be saved automatically")
print("2. 🚀 Run the JobTracker app")
print("3. 📧 Test Gmail email fetching")
print("4. 🤖 Test email categorization")
