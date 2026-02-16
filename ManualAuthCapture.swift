import Foundation
import AppKit

print("🔗 Manual Gmail Authentication")
print(String(repeating: "=", count: 50))
print("📝 Step 1: Click this authentication link:")
print()

let authURL = "https://accounts.google.com/o/oauth2/v2/auth?client_id=99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com&redirect_uri=http://localhost:8080/callback&response_type=code&scope=https://www.googleapis.com/auth/gmail.readonly&access_type=offline&prompt=consent"

print("🌐 \(authURL)")
print()
print("📝 Step 2: After authentication, you'll be redirected to a URL like:")
print("http://localhost:8080/callback?code=4/0AfrIepAHsVxAcpMM8GS-TW-XDJSb9qtyfkFGwsWPdSNS11Z6VrtbM6y1Ge8QCaZFtr2X8Q&scope=https://www.googleapis.com/auth/gmail.readonly")
print()
print("📝 Step 3: Copy the authorization code (the part after 'code=')")
print("📝 Step 4: Paste it below when prompted")
print()

print("🚀 Opening authentication URL...")
if NSWorkspace.shared.open(URL(string: authURL)!) {
    print("✅ Browser opened!")
} else {
    print("ℹ️ Please manually copy the URL above")
}

print()
print("⏳ Waiting for you to complete authentication...")
print("📝 Please complete the authentication in your browser, then:")
print("   1. Copy the authorization code from the callback URL")
print("   2. Paste it here and press Enter")

print()
print("📝 Enter authorization code (or press Enter to exit):")

if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
    print("🔄 Exchanging code for tokens...")
    exchangeCodeForTokens(input)
} else {
    print("❌ No code provided. Exiting.")
}

func exchangeCodeForTokens(_ code: String) {
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
    
    let semaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Token exchange failed: \(error.localizedDescription)")
            semaphore.signal()
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
                        saveTokensToFile(accessToken: accessToken, refreshToken: refreshToken)
                        
                        // Test the token
                        testAccessToken(accessToken)
                        
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
        
        semaphore.signal()
    }.resume()
    
    semaphore.wait()
}

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
    } catch {
        print("❌ Failed to save tokens: \(error)")
    }
}

func testAccessToken(_ accessToken: String) {
    print("\n🔄 Testing access token...")
    
    guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
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
                print("✅ Access token works perfectly!")
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let emailAddress = json["emailAddress"] as? String {
                        print("🎉 Successfully connected to Gmail: \(emailAddress)")
                    }
                }
                
                print("\n🎉🎉🎉 GMAIL AUTHENTICATION COMPLETE! 🎉🎉🎉")
                print("🚀 Your JobTracker app is now ready!")
                
            } else {
                print("❌ Token test failed: \(httpResponse.statusCode)")
            }
        }
        
        testSemaphore.signal()
    }.resume()
    
    testSemaphore.wait()
}
