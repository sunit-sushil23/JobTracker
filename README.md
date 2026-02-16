# JobTracker - Smart Job Application Manager

A macOS SwiftUI application that automatically tracks job applications by reading your Gmail emails and categorizing them using AI.

## ✨ Features

- 📧 **Gmail Integration**: Automatically reads job application emails from your Gmail
- 🤖 **AI Categorization**: Uses Ollama/LLM to intelligently categorize job applications
- 📊 **Kanban Board**: Visual job tracking with status columns (Applied, Screening, Interview, Offer, Rejected)
- 🔄 **Real-time Updates**: Live status tracking and transitions
- 📱 **Native macOS App**: Built with SwiftUI for optimal performance

## 🚀 Quick Start

### Prerequisites

1. **macOS 13.0+** (Ventura or later)
2. **Xcode 14.0+**
3. **Google Cloud Project** with Gmail API enabled
4. **Ollama** (optional, for AI categorization)

### Gmail Setup

1. **Create Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project
   - Enable Gmail API

2. **Create OAuth Credentials**
   - Go to APIs & Services → Credentials
   - Click "Create Credentials" → "OAuth 2.0 Client ID"
   - Select "Web application"
   - Add redirect URI: `http://localhost:8080/callback`
   - Copy Client ID and Client Secret

3. **Update App Credentials**
   - Update the client ID and secret in `GmailService.swift`
   - Or use the built-in authentication flow

### Ollama Setup (Optional)

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama
ollama serve

# Pull a model
ollama pull llama2
# or
ollama pull mistral
```

## 📱 Installation & Running

### Using Xcode

1. Clone this repository
2. Open `JobTracker.xcodeproj` in Xcode
3. Select your development team in signing settings
4. Run the app (Cmd+R)

### Authentication

1. **First Run**: Click "Authenticate Gmail" in the app
2. **Browser Authentication**: Complete Google OAuth flow
3. **Automatic Processing**: App will fetch and categorize emails

## 🎯 How It Works

### 1. Gmail Authentication
- Uses OAuth 2.0 for secure Gmail access
- Multiple authentication methods available
- Automatic token refresh and persistence

### 2. Email Processing
- Searches for job-related emails using smart queries
- Fetches email content and metadata
- Identifies job applications, interviews, offers, and rejections

### 3. AI Categorization
- **Primary**: Uses Ollama LLM for intelligent categorization
- **Fallback**: Rule-based categorization when Ollama unavailable
- Extracts company names, positions, and application status

### 4. Kanban Tracking
- Visual job tracking with drag-and-drop
- Status transitions with notes
- Historical tracking of application progress

## 📊 Email Search Queries

The app searches for emails containing:
- `application OR applied OR interview OR job OR position OR resume OR cover letter`

This captures most job-related communications while filtering out spam and newsletters.

## 🧪 Testing

### Gmail Authentication Test
```bash
cd JobTracker
./GmailAuthStandaloneTest
```

### Email Categorization Test
```bash
./EmailCategorizationTest
```

### Full Integration Test
Run the app and use "Integration Tests" from the menu.

## 🔧 Configuration

### Gmail API Scopes
- `https://www.googleapis.com/auth/gmail.readonly`
- Read-only access to Gmail emails

### App Entitlements
- Network client access
- Network server access (for OAuth callback)
- File system access (for token storage)

## 📁 Project Structure

```
JobTracker/
├── Models/
│   ├── JobModel.swift          # Job data models
│   └── JobStore.swift          # Job data management
├── Services/
│   ├── GmailService.swift      # Gmail API integration
│   ├── OllamaService.swift     # AI categorization
│   └── OAuthCallbackServer.swift # OAuth callback handling
├── Views/
│   ├── ContentView.swift       # Main app interface
│   ├── KanbanBoard.swift       # Kanban board view
│   └── JobCard.swift          # Job card component
├── Tests/
│   ├── GmailAuthTest.swift     # Authentication tests
│   └── EmailCategorizationTest.swift # Categorization tests
└── Documentation/
    ├── README_Gmail_Fix.md    # Gmail setup guide
    └── TEST_RESULTS_SUMMARY.md # Test results
```

## 🐛 Troubleshooting

### Gmail Authentication Issues

**"OAuth client not found"**
- Verify Client ID and Secret are correct
- Check Google Cloud Console project selection
- Ensure Gmail API is enabled

**"Redirect URI mismatch"**
- Add `http://localhost:8080/callback` to your OAuth client
- Check for exact match including protocol and port

**"Network server failed"**
- Ensure app has proper entitlements
- Check if port 8080 is available

### Email Categorization Issues

**Ollama not connected**
- Install and start Ollama: `ollama serve`
- Pull a model: `ollama pull llama2`
- Check if port 11434 is accessible

**Poor categorization results**
- Try different Ollama models
- Check email content for job-related keywords
- Review categorization confidence scores

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Google Gmail API for email access
- Ollama for local AI processing
- SwiftUI for native macOS interface
- AuthenticationServices for secure OAuth flow

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review test results in `TEST_RESULTS_SUMMARY.md`
3. Create an issue with detailed error information

---

**Built with ❤️ for job seekers** 🚀
