import Foundation

// Quick test to verify Gmail API is enabled and accessible
print("🧪 Quick Gmail API Test")
print(String(repeating: "=", count: 40))

// Test 1: Check if Gmail API endpoint is reachable
print("\n📧 Testing Gmail API endpoint...")

guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else {
    print("❌ Invalid Gmail API URL")
    exit(1)
}

var request = URLRequest(url: url)
request.setValue("Bearer invalid_token", forHTTPHeaderField: "Authorization")
request.timeoutInterval = 10.0

let semaphore = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Network error: \(error.localizedDescription)")
        print("🔧 Check your internet connection")
        semaphore.signal()
        return
    }
    
    if let httpResponse = response as? HTTPURLResponse {
        print("📊 Response Status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 401:
            print("✅ Gmail API is accessible!")
            print("📝 Got 401 (Unauthorized) which means:")
            print("   - Gmail API is enabled")
            print("   - Endpoint is reachable")
            print("   - Just needs valid authentication token")
            
        case 403:
            print("⚠️ Gmail API might not be enabled")
            print("🔧 Got 403 (Forbidden) - check if Gmail API is enabled in Google Cloud Console")
            
        case 404:
            print("❌ Gmail API not found")
            print("🔧 Gmail API might not be enabled or URL is incorrect")
            
        default:
            print("📝 Unexpected status: \(httpResponse.statusCode)")
        }
        
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📝 Response: \(json)")
        }
    }
    
    semaphore.signal()
}.resume()

semaphore.wait()

print("\n" + String(repeating: "=", count: 40))
print("📋 Next Steps:")
print("✅ If you see 401 status: Gmail API is working, proceed with authentication")
print("⚠️ If you see 403/404: Enable Gmail API in Google Cloud Console")
print("🚀 Ready for real Gmail authentication test!")
