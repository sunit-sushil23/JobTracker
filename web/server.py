#!/usr/bin/env python3
"""
Simple HTTP server for JobTracker Web App
Run this with: python3 server.py
Then open http://localhost:8000 in your browser
"""

import http.server
import socketserver
import webbrowser
import os
import threading
import time

PORT = 8000

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.dirname(os.path.abspath(__file__)), **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def open_browser():
    """Open browser after a short delay"""
    time.sleep(1)
    webbrowser.open(f'http://localhost:{PORT}')

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"""
🚀 JobTracker Web Server Started!
📍 Open: http://localhost:{PORT}
📧 Gmail integration ready
📋 Kanban board ready
🔄 Auto-refresh enabled

Press Ctrl+C to stop server
        """)
        
        # Open browser in a separate thread
        browser_thread = threading.Thread(target=open_browser)
        browser_thread.daemon = True
        browser_thread.start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Server stopped")
