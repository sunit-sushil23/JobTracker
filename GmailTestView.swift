import SwiftUI

struct GmailTestView: View {
    @StateObject private var gmailService = GmailService()
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Gmail Authentication Test")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // Authentication Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Authentication Status:")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Circle()
                        .fill(gmailService.isAuthenticated ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(gmailService.isAuthenticated ? "Authenticated" : "Not Authenticated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let error = gmailService.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Authentication Methods
            VStack(alignment: .leading, spacing: 12) {
                Text("Test Authentication Methods:")
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Button("Method 1: OAuth Web Flow") {
                        testAuthMethod(.oauthWebFlow)
                    }
                    .disabled(gmailService.isLoading)
                    
                    Button("Method 2: OAuth WebView") {
                        testAuthMethod(.oauthWebView)
                    }
                    .disabled(gmailService.isLoading)
                    
                    Button("Method 3: Direct Auth Session") {
                        testAuthMethod(.directAuth)
                    }
                    .disabled(gmailService.isLoading)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Test Authentication
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Test Current Authentication:")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if gmailService.isAuthenticated {
                        Button("Test API Access") {
                            testAPIAccess()
                        }
                        .disabled(isRunningTests)
                    }
                }
                
                if isRunningTests {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Test Results
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Results:")
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(testResults, id: \.self) { result in
                                Text(result)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(result.contains("✅") ? Color.green.opacity(0.1) : 
                                              result.contains("❌") ? Color.red.opacity(0.1) : 
                                              Color.yellow.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Loading Indicator
            if gmailService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Authenticating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Clear Results") {
                    testResults.removeAll()
                }
                
                Spacer()
                
                if gmailService.isAuthenticated {
                    Button("Logout") {
                        gmailService.logout()
                        addTestResult("🔒 Logged out")
                    }
                }
                
                Button("Close") {
                    // Close window or dismiss
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            addTestResult("🧪 Gmail Test View loaded")
            addTestResult("📧 Authentication status: \(gmailService.isAuthenticated ? "✅ Authenticated" : "❌ Not authenticated")")
        }
    }
    
    private func testAuthMethod(_ method: GmailAuthMethod) {
        addTestResult("🔄 Testing \(method)...")
        gmailService.authenticate(with: method)
        
        // Monitor authentication result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if gmailService.isAuthenticated {
                addTestResult("✅ \(method) successful!")
            } else if let error = gmailService.error {
                addTestResult("❌ \(method) failed: \(error)")
            } else {
                addTestResult("⏳ \(method) in progress...")
            }
        }
    }
    
    private func testAPIAccess() {
        isRunningTests = true
        addTestResult("🔄 Testing API access...")
        
        Task {
            let success = await gmailService.testAuthentication()
            
            await MainActor.run {
                isRunningTests = false
                if success {
                    addTestResult("✅ API access successful!")
                    
                    // Test email fetching
                    Task {
                        await testEmailFetching()
                    }
                } else {
                    addTestResult("❌ API access failed: \(gmailService.error ?? "Unknown error")")
                }
            }
        }
    }
    
    private func testEmailFetching() async {
        await MainActor.run {
            addTestResult("🔄 Testing email fetching...")
        }
        
        do {
            let emails = try await gmailService.fetchJobApplicationEmails()
            
            await MainActor.run {
                addTestResult("✅ Email fetching successful!")
                addTestResult("📧 Found \(emails.count) job-related emails")
                
                // Show first few email subjects
                for (index, email) in emails.prefix(3).enumerated() {
                    addTestResult("📧 \(index + 1). \(email.subject)")
                }
                
                if emails.count > 3 {
                    addTestResult("📧 ... and \(emails.count - 3) more")
                }
            }
        } catch {
            await MainActor.run {
                addTestResult("❌ Email fetching failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func addTestResult(_ result: String) {
        DispatchQueue.main.async {
            testResults.append("[\(DateFormatter.timeFormatter.string(from: Date()))] \(result)")
        }
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    GmailTestView()
}
