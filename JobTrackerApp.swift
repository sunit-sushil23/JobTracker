import SwiftUI

@main
struct JobTrackerApp: App {
    @StateObject private var jobStore = JobStore()
    @StateObject private var gmailService = GmailService()
    @StateObject private var ollamaService = OllamaService()
    @StateObject private var transitionStore = StatusTransitionStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(jobStore)
                .environmentObject(gmailService)
                .environmentObject(ollamaService)
                .environmentObject(transitionStore)
        }
    }
}
