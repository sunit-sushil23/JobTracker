import Foundation

print("🔑 Simple Gmail Token Test")
print(String(repeating: "=", count: 40))
print("📝 Let's create tokens manually with curl")
print()

// First, let's create a simple test that shows the exact curl command
print("📋 Step 1: Get authorization code")
print("🌐 Open this URL in your browser:")
print()

let authURL = "https://accounts.google.com/o/oauth2/v2/auth?client_id=99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com&redirect_uri=http://localhost:8080/callback&response_type=code&scope=https://www.googleapis.com/auth/gmail.readonly&access_type=offline&prompt=consent"

print(authURL)
print()
print("📝 After you authenticate, you'll get a URL like:")
print("http://localhost:8080/callback?code=4/0AfrIepAHsVxAcpMM8GS-TW-XDJSb9qtyfkFGwsWPdSNS11Z6VrtbM6y1Ge8QCaZFtr2X8Q&scope=https://www.googleapis.com/auth/gmail.readonly")
print()
print("📝 Copy the authorization code (the part after 'code=')")
print()

print("📋 Step 2: Exchange code for tokens")
print("📝 Use this curl command (replace YOUR_CODE_HERE with the actual code):")
print()

let curlCommand = """
curl -X POST \\
  "https://oauth2.googleapis.com/token" \\
  -H "Content-Type: application/x-www-form-urlencoded" \\
  -d "client_id=99861683980-hdnk82l1t3o9dih99tpvefol7rb63h2n.apps.googleusercontent.com&client_secret=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&code=YOUR_CODE_HERE&grant_type=authorization_code&redirect_uri=http://localhost:8080/callback"
"""

print(curlCommand)
print()
print("📝 The response will contain your access_token and refresh_token")
print()
print("📋 Step 3: Create tokens file")
print("📝 Create a file at ~/Documents/gmail_tokens.json with this content:")
print()

let tokensJSON = """
{
  "access_token": "YOUR_ACCESS_TOKEN_HERE",
  "refresh_token": "YOUR_REFRESH_TOKEN_HERE",
  "saved_at": \(Date().timeIntervalSince1970)
}
"""

print(tokensJSON)
print()
print("📋 Step 4: Test the tokens")
print("📝 Then run this to test:")
print("curl -H \"Authorization: Bearer YOUR_ACCESS_TOKEN_HERE\" \"https://www.googleapis.com/gmail/v1/users/me/profile\"")
print()
print("🚀 That's it! The JobTracker app will automatically load the tokens")
print("📱 No more complex authentication needed!")

print(String(repeating: "=", count: 40))
print("✅ Simple instructions ready!")
