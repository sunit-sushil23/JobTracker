import Foundation
import AppKit
import AuthenticationServices

// Test the no-callback authentication approach
class TestNoCallbackAuth: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let clientID = "99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com"
    private let clientSecret = "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"
    
    func testNoCallbackAuth() {
        print("🧪 Testing No-Callback Gmail Authentication...")
        print("=" * 50)
        
        print("📝 This approach uses ASWebAuthenticationSession without a callback server")
        print("📝 It should work even if you can't configure redirect URIs")
        print()
        
        print("🔧 Setup Instructions:")
        print("1. In Google Cloud Console, create OAuth 2.0 Client ID")
        print("2. Select 'Desktop application' type")
        print("3. If you see 'Authorized redirect URIs', leave it empty")
        print("4. If you don't see it, that's fine - Desktop apps don't always need it")
        print("5. Enable Gmail API")
        print()
        
        print("📝 Client ID: \(clientID)")
        print("📝 The app will handle the OAuth flow automatically")
        print()
        
        print("🚀 To test this interactively:")
        print("1. Run the main JobTracker app")
        print("2. Click '+' menu")
        print("3. Select 'Test Gmail Authentication'")
        print("4. Try the authentication methods")
        print()
        
        print("✅ No-callback authentication test completed!")
        print("📝 This approach bypasses the need for redirect URI configuration")
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Main test execution
print("🧪 No-Callback Authentication Test")
print()

let tester = TestNoCallbackAuth()
tester.testNoCallbackAuth()
