import SwiftUI

struct TestAuthentication: View {
    @StateObject private var gmailService = GmailService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Authentication Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Authenticated: \(gmailService.isAuthenticated ? "YES ✅" : "NO ❌")")
                .font(.headline)
                .foregroundColor(gmailService.isAuthenticated ? .green : .red)
            
            Text("Access Token: \(gmailService.accessToken != nil ? "EXISTS ✅" : "MISSING ❌")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if gmailService.isAuthenticated {
                Text("🎉 Auto-authentication worked!")
                    .font(.body)
                    .foregroundColor(.green)
                    .padding()
            } else {
                Button("Force Auto-Auth") {
                    // This should trigger auto-auth
                    print("Testing auto-auth...")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            print("🔍 Test view appeared - checking auth status...")
            print("Is Authenticated: \(gmailService.isAuthenticated)")
            print("Has Access Token: \(gmailService.accessToken != nil)")
        }
    }
}

#Preview {
    TestAuthentication()
}
