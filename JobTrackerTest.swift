import SwiftUI

struct JobTrackerTest: View {
    @StateObject private var gmailService = GmailService()
    @StateObject private var ollamaService = OllamaService()
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var currentTest = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Job Tracker Integration Test")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // Service Status
            VStack(alignment: .leading, spacing: 12) {
                Text("Service Status:")
                    .fontWeight(.semibold)
                
                HStack {
                    Circle()
                        .fill(gmailService.isAuthenticated ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text("Gmail: \(gmailService.isAuthenticated ? "✅ Authenticated" : "❌ Not Authenticated")")
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(ollamaService.isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text("Ollama: \(ollamaService.isConnected ? "✅ Connected" : "❌ Disconnected")")
                        .font(.caption)
                }
                
                if ollamaService.isConnected {
                    Text("Models: \(ollamaService.availableModels.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Test Controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Integration Tests:")
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Button("Test Gmail Authentication") {
                        testGmailAuthentication()
                    }
                    .disabled(isRunningTests || gmailService.isAuthenticated)
                    
                    Button("Test Gmail API Access") {
                        testGmailAPI()
                    }
                    .disabled(isRunningTests || !gmailService.isAuthenticated)
                    
                    Button("Test Email Categorization") {
                        testEmailCategorization()
                    }
                    .disabled(isRunningTests)
                    
                    Button("Test Full Workflow") {
                        testFullWorkflow()
                    }
                    .disabled(isRunningTests || !gmailService.isAuthenticated)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Current Test Status
            if isRunningTests {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Running: \(currentTest)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Test Results
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Results:")
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Clear") {
                            testResults.removeAll()
                        }
                        .font(.caption)
                    }
                    
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
                                              result.contains("⚠️") ? Color.yellow.opacity(0.1) :
                                              Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Run All Tests") {
                    runAllTests()
                }
                .disabled(isRunningTests)
                
                Spacer()
                
                Button("Close") {
                    // Close window or dismiss
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onAppear {
            addTestResult("🧪 Job Tracker Test View loaded")
            checkInitialStatus()
        }
    }
    
    private func checkInitialStatus() {
        addTestResult("📧 Gmail Status: \(gmailService.isAuthenticated ? "✅ Authenticated" : "❌ Not Authenticated")")
        addTestResult("🤖 Ollama Status: \(ollamaService.isConnected ? "✅ Connected" : "❌ Disconnected")")
        
        if ollamaService.isConnected {
            addTestResult("📦 Available Models: \(ollamaService.availableModels.joined(separator: ", "))")
        }
    }
    
    private func testGmailAuthentication() {
        isRunningTests = true
        currentTest = "Gmail Authentication"
        addTestResult("🔄 Starting Gmail authentication test...")
        
        gmailService.authenticate(with: .directAuth)
        
        // Monitor authentication result
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if gmailService.isAuthenticated {
                addTestResult("✅ Gmail authentication successful!")
            } else if let error = gmailService.error {
                addTestResult("❌ Gmail authentication failed: \(error)")
            } else {
                addTestResult("⏳ Gmail authentication still in progress...")
            }
            isRunningTests = false
        }
    }
    
    private func testGmailAPI() {
        isRunningTests = true
        currentTest = "Gmail API Access"
        addTestResult("🔄 Testing Gmail API access...")
        
        Task {
            let success = await gmailService.testAuthentication()
            
            await MainActor.run {
                if success {
                    addTestResult("✅ Gmail API access successful!")
                    
                    // Test email fetching
                    Task {
                        await testEmailFetching()
                    }
                } else {
                    addTestResult("❌ Gmail API access failed: \(gmailService.error ?? "Unknown error")")
                }
                isRunningTests = false
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
                
                // Show first few email details
                for (index, email) in emails.prefix(3).enumerated() {
                    addTestResult("📧 \(index + 1). \(email.subject)")
                    addTestResult("   From: \(email.from)")
                    addTestResult("   Date: \(DateFormatter.shortFormatter.string(from: email.date))")
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
    
    private func testEmailCategorization() {
        isRunningTests = true
        currentTest = "Email Categorization"
        addTestResult("🔄 Testing email categorization...")
        
        let testEmails = [
            """
            Subject: Application Received - Software Engineer Position
            
            Dear Candidate,
            
            Thank you for your interest in the Software Engineer position at TechCorp. 
            We have received your application and will review it carefully. Our team will 
            get back to you within 5-7 business days.
            
            Best regards,
            TechCorp HR Team
            hr@techcorp.com
            """,
            
            """
            Subject: Technical Interview - Senior Developer Role
            
            Hi there,
            
            We'd like to schedule a technical interview for the Senior Developer position. 
            The interview will include a coding challenge and system design discussion.
            
            Are you available next Tuesday or Wednesday?
            
            Thanks,
            Sarah Johnson
            Acme Inc. Recruiting
            sarah@acme.com
            """,
            
            """
            Subject: Job Offer - Product Manager
            
            Congratulations! We're pleased to offer you the Product Manager position at StartupXYZ.
            
            Offer Details:
            - Salary: $120,000
            - Start Date: Monday, March 15, 2024
            - Location: San Francisco, CA (Hybrid)
            
            Please review and sign the offer letter by Friday.
            
            Best regards,
            Michael Chen
            VP of Engineering
            StartupXYZ
            """,
            
            """
            Subject: Your Weekly Tech Newsletter
            
            Check out this week's top tech stories and job market insights!
            
            1. AI Trends in 2024
            2. Remote Work Statistics
            3. Startup Funding Roundup
            
            Unsubscribe | Preferences | View in Browser
            """
        ]
        
        Task {
            for (index, email) in testEmails.enumerated() {
                await MainActor.run {
                    addTestResult("🧪 Testing email \(index + 1)...")
                }
                
                let categorization = await ollamaService.categorizeEmail(email)
                
                await MainActor.run {
                    let result = categorization.isJobApplication ? "✅ Job Application" : "❌ Not Job Application"
                    addTestResult("   \(result)")
                    addTestResult("   🏢 Company: \(categorization.companyName ?? "Unknown")")
                    addTestResult("   💼 Position: \(categorization.positionName ?? "Unknown")")
                    addTestResult("   📊 Status: \(categorization.detectedStatus?.rawValue ?? "Unknown")")
                    addTestResult("   🎯 Confidence: \(String(format: "%.2f", categorization.confidence))")
                    
                    if let reason = categorization.extractedInfo["reason"] {
                        addTestResult("   📝 Reason: \(reason)")
                    }
                }
            }
            
            await MainActor.run {
                addTestResult("✅ Email categorization tests completed!")
                isRunningTests = false
            }
        }
    }
    
    private func testFullWorkflow() {
        isRunningTests = true
        currentTest = "Full Workflow"
        addTestResult("🔄 Starting full workflow test...")
        
        Task {
            // Step 1: Test Gmail authentication
            if !gmailService.isAuthenticated {
                await MainActor.run {
                    addTestResult("⚠️ Gmail not authenticated, skipping full workflow")
                    isRunningTests = false
                }
                return
            }
            
            await MainActor.run {
                addTestResult("✅ Step 1: Gmail authenticated")
            }
            
            // Step 2: Fetch emails
            do {
                let emails = try await gmailService.fetchJobApplicationEmails()
                
                await MainActor.run {
                    addTestResult("✅ Step 2: Fetched \(emails.count) emails")
                }
                
                // Step 3: Categorize emails
                var jobApplications = 0
                
                for (index, email) in emails.prefix(5).enumerated() {
                    let categorization = await ollamaService.categorizeEmail(email.content)
                    
                    if categorization.isJobApplication {
                        jobApplications += 1
                        
                        await MainActor.run {
                            addTestResult("📧 Job Application \(jobApplications): \(categorization.companyName ?? "Unknown") - \(categorization.positionName ?? "Unknown")")
                        }
                    }
                }
                
                await MainActor.run {
                    addTestResult("✅ Step 3: Categorized \(jobApplications) job applications from \(emails.count) emails")
                    addTestResult("✅ Full workflow test completed successfully!")
                }
                
            } catch {
                await MainActor.run {
                    addTestResult("❌ Full workflow failed: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    private func runAllTests() {
        addTestResult("🚀 Starting all tests...")
        
        // Run tests in sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !gmailService.isAuthenticated {
                testGmailAuthentication()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    if gmailService.isAuthenticated {
                        testGmailAPI()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            testEmailCategorization()
                        }
                    } else {
                        addTestResult("⚠️ Skipping Gmail tests - authentication failed")
                        testEmailCategorization()
                    }
                }
            } else {
                testGmailAPI()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    testEmailCategorization()
                }
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
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    JobTrackerTest()
}
