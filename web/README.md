# JobTracker Web Version

A web-based job tracking application with Gmail integration that works entirely in your browser!

## 🚀 Quick Start

### Option 1: Python Server (Recommended)
```bash
cd web
python3 server.py
```

### Option 2: Any HTTP Server
```bash
cd web
python3 -m http.server 8000
# or
npx serve .
# or
php -S localhost:8000
```

Then open: **http://localhost:8000**

## ✨ Features

### 📧 Gmail Integration
- **Browser-based OAuth** - No desktop app issues
- **Direct token handling** - Secure and reliable
- **Automatic email fetching** - Finds job applications
- **Smart categorization** - AI-powered job extraction

### 📋 Kanban Board
- **Drag & drop** - Move jobs between stages
- **5 stages**: Applied → Screening → Interview → Offer → Rejected
- **Visual tracking** - See your job search progress
- **Local storage** - Data saved in browser

### 🔧 Key Advantages

**✅ No Desktop App Issues:**
- No Xcode compilation problems
- No macOS entitlement issues
- No OAuth callback server problems
- No "testing mode" restrictions

**✅ Browser-Native Authentication:**
- Uses Google's web OAuth flow
- Handles redirects properly
- No popup blocking issues
- Works with existing browser sessions

**✅ Simple Setup:**
- Just run the server
- Open in browser
- Authenticate with Google
- Start tracking jobs

## 🎯 How to Use

### 1. Start the App
```bash
cd web
python3 server.py
```

### 2. Authenticate Gmail
1. Click "Authenticate Gmail"
2. Sign in with your Google account
3. Grant permissions
4. Automatic redirect back to app

### 3. Fetch Job Emails
1. Click "Fetch from Gmail"
2. Watch progress bar
3. See jobs appear on Kanban board
4. Jobs automatically categorized

### 4. Manage Jobs
- **Drag jobs** between columns
- **Add jobs manually** with "Add Job Manually"
- **View job details** by clicking cards
- **Data persists** in browser storage

## 🔧 Configuration

### Gmail OAuth Setup
The app uses these Google OAuth settings:
- **Client ID**: Built-in (for testing)
- **Redirect URI**: `http://localhost:8000/callback.html`
- **Scopes**: Gmail read-only access

### For Production Use
1. Create your own Google Cloud project
2. Update CLIENT_ID in `index.html`
3. Set proper redirect URI

## 📱 Browser Compatibility

- ✅ Chrome (recommended)
- ✅ Safari
- ✅ Firefox
- ✅ Edge

## 🔒 Security & Privacy

- **Tokens stored locally** in browser storage
- **Read-only Gmail access**
- **No data sent to external servers**
- **Works completely offline** after authentication

## 🛠️ Troubleshooting

### Authentication Issues
- **Clear browser cache** and try again
- **Use incognito mode** for fresh session
- **Check popup blockers** - allow localhost
- **Ensure Google account** has job emails

### Gmail Access Issues
- **Verify Gmail API** is enabled
- **Check permissions** were granted
- **Try re-authenticating** with fresh token

### Server Issues
- **Check port 8000** is available
- **Try different port** with `python3 -m http.server 8080`
- **Ensure Python 3** is installed

## 📊 Data Storage

- **Browser localStorage** - No database required
- **Automatic save** - Jobs persist between sessions
- **Export option** - Can be added later
- **Import option** - Can be added later

## 🚀 Next Steps

This web version provides:
- ✅ **Working Gmail integration**
- ✅ **No authentication loops**
- ✅ **Simple setup**
- ✅ **Cross-platform compatibility**

Perfect alternative to the desktop app while OAuth issues are resolved!
