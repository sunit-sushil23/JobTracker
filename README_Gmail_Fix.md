# Gmail Authentication Fix & Testing Guide

## Issues Fixed

### 1. Gmail Authentication Problems
- **Problem**: Original OAuth flow was unreliable with single authentication method
- **Solution**: Added 3 authentication methods:
  - OAuth Web Flow (improved with timeout)
  - OAuth WebView (embedded browser)
  - Direct Auth Session (native macOS)

### 2. Token Management
- **Problem**: No token refresh mechanism
- **Solution**: Added automatic token refresh and better token storage

### 3. Error Handling
- **Problem**: Poor error messages and no recovery
- **Solution**: Comprehensive error handling with specific error messages

### 4. Email Categorization
- **Problem**: Ollama dependency without fallback
- **Solution**: Added rule-based categorization as fallback when Ollama unavailable

## New Features

### Improved Gmail Service (`GmailServiceImproved.swift`)
- Multiple authentication methods
- Token refresh capability
- Better error handling
- Test authentication function
- Improved timeout handling

### Enhanced Ollama Service (`OllamaServiceImproved.swift`)
- Automatic model detection
- Rule-based categorization fallback
- Better prompt engineering
- Improved information extraction
- Test categorization function

### Testing Tools
- `GmailTestView.swift` - Test Gmail authentication
- `JobTrackerTest.swift` - Full integration tests
- `GmailAuthManualTest.swift` - Manual authentication testing

## How to Test

### 1. Basic Connectivity Test
```bash
cd JobTester
swiftc main.swift -framework Foundation
./main
```

### 2. Gmail Authentication Test
1. Open the JobTracker app
2. Click the "+" menu button
3. Select "Test Gmail Authentication"
4. Try different authentication methods:
   - Method 1: OAuth Web Flow (opens browser)
   - Method 2: OAuth WebView (embedded)
   - Method 3: Direct Auth Session (native)

### 3. Full Integration Test
1. In the app, click "+" menu
2. Select "Integration Tests"
3. Click "Run All Tests"
4. This will test:
   - Gmail authentication
   - Gmail API access
   - Email fetching
   - Email categorization
   - Full workflow

### 4. Manual Testing
If automated tests fail, you can test manually:

#### Gmail Authentication
```swift
let gmailService = GmailServiceImproved()
gmailService.authenticate(with: .directAuth) // or .oauthWebFlow, .oauthWebView
```

#### Email Categorization
```swift
let ollamaService = OllamaServiceImproved()
let testEmail = """
Subject: Application Received - Software Engineer

Dear Candidate,
Thank you for applying to TechCorp...
"""

let categorization = await ollamaService.categorizeEmail(testEmail)
print("Is job application: \(categorization.isJobApplication)")
print("Company: \(categorization.companyName ?? "Unknown")")
print("Position: \(categorization.positionName ?? "Unknown")")
```

## Troubleshooting

### Gmail Authentication Issues

1. **"OAuth client not found" error**
   - Check if client ID is correct in Google Cloud Console
   - Ensure OAuth 2.0 Client ID is created for "Desktop application"

2. **"Invalid redirect URI" error**
   - Make sure `http://localhost:8080/callback` is added to authorized redirect URIs
   - Check for exact match including protocol and port

3. **"Network server failed" error**
   - Ensure app has proper entitlements (network.server)
   - Check if port 8080 is available

4. **Authentication timeout**
   - Try the Direct Auth Session method (Method 3)
   - Check network connection
   - Ensure Google is accessible from your network

### Ollama Issues

1. **"Failed to connect to Ollama"**
   - Ensure Ollama is running: `ollama serve`
   - Check if port 11434 is available
   - The app will fallback to rule-based categorization

2. **No models available**
   - Install a model: `ollama pull llama2` or `ollama pull mistral`
   - The app will auto-detect available models

### Email Processing Issues

1. **"No emails found"**
   - Check Gmail query in `fetchJobApplicationEmails()`
   - Ensure you have job-related emails in your Gmail
   - Verify Gmail API permissions

2. **Poor categorization results**
   - Test with the sample emails in the integration test
   - Check if Ollama is connected for better results
   - Rule-based fallback should work for basic cases

## Required Setup

### Google Cloud Console
1. Go to Google Cloud Console
2. Create OAuth 2.0 Client ID for "Desktop application"
3. Add redirect URI: `http://localhost:8080/callback`
4. Enable Gmail API
5. Copy client ID and secret to the app

### Ollama (Optional but recommended)
1. Install Ollama: https://ollama.ai
2. Start Ollama: `ollama serve`
3. Pull a model: `ollama pull llama2` or `ollama pull mistral`

### App Permissions
The app requires these entitlements (already configured):
- `com.apple.security.network.client`
- `com.apple.security.network.server`
- `com.apple.security.files.user-selected.read-write`

## Testing Results Expected

### Successful Authentication
- ✅ Gmail authentication successful!
- 🔑 Access token: eyJhbGciOi...
- 🔄 Refresh token: eyJhbGciOi...

### Successful API Test
- ✅ Gmail API test successful!
- ✅ Token refresh successful!

### Successful Email Fetching
- ✅ Email fetching successful!
- 📧 Found X job-related emails

### Successful Categorization
- ✅ Job Application
- 🏢 Company: TechCorp
- 💼 Position: Software Engineer
- 📊 Status: Applied
- 🎯 Confidence: 0.85

## Next Steps

1. Run the integration tests to verify everything works
2. Test with your actual Gmail account
3. Process some job application emails
4. Verify categorization accuracy
5. Check that jobs are created correctly in the Kanban board

## Support

If you encounter issues:
1. Check the test results for specific error messages
2. Try different authentication methods
3. Verify Google Cloud Console setup
4. Ensure Ollama is running if using AI categorization
5. Check network connectivity
