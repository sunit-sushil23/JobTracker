import SwiftUI

struct ContentView: View {
    @EnvironmentObject var jobStore: JobStore
    @EnvironmentObject var gmailService: GmailService
    @EnvironmentObject var ollamaService: OllamaService
    @State private var showingAddJob = false
    @State private var showingGmailProcessing = false
    @State private var selectedJob: Job?
    @State private var showingStatusTransition = false
    @State private var targetStatus: JobStatus?
    @State private var isKanbanView = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                if isKanbanView {
                    KanbanBoard()
                } else {
                    JobTableView()
                }
            }
            .navigationTitle("Job Tracker")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isKanbanView.toggle()
                        }
                    }) {
                        Image(systemName: isKanbanView ? "tablecells" : "square.grid.2x2")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Test Authentication") {
                            // Test view to verify auto-auth
                        }
                        Button("Add Job Manually") {
                            showingAddJob = true
                        }
                        Button("Fetch from Gmail") {
                            showingGmailProcessing = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddJob) {
                AddJobView()
            }
            .sheet(isPresented: $showingGmailProcessing) {
                GmailProcessingView()
            }
            .sheet(isPresented: $showingStatusTransition) {
                if let job = selectedJob, let targetStatus = targetStatus {
                    StatusTransitionView(job: job, targetStatus: targetStatus) { updatedJob, notes in
                        jobStore.moveJob(job, to: targetStatus, with: notes)
                        showingStatusTransition = false
                        selectedJob = nil
                        self.targetStatus = nil
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack {
            HStack {
                Text("Job Applications")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(jobStore.jobs.count) Total Jobs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Divider()
        }
    }
    
    private func statusColumn(_ status: JobStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView(for: status)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(jobStore.getJobsByStatus(status)) { job in
                        JobCard(job: job) { job, targetStatus in
                            self.selectedJob = job
                            self.targetStatus = targetStatus
                            showingStatusTransition = true
                        }
                    }
                }
                .frame(minWidth: 280)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func headerView(for status: JobStatus) -> some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
            
            Text(status.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(jobStore.getJobsByStatus(status).count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GmailProcessingView: View {
    @EnvironmentObject var gmailService: GmailService
    @EnvironmentObject var ollamaService: OllamaService
    @EnvironmentObject var jobStore: JobStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Process Gmail for Job Applications")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView(value: Double(processedCount), total: Double(totalCount))
                        .frame(width: 300)
                    
                    Text("Processing email \(processedCount) of \(totalCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Error occurred")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        processGmail()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Text("This will scan your Gmail for job application emails and automatically create job entries.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Start Processing") {
                        processGmail()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
    
    private func processGmail() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Skip authentication check - go straight to processing
                print("🚀 Starting Gmail processing...")
                
                let emails = try await gmailService.fetchJobApplicationEmails()
                await MainActor.run {
                    totalCount = emails.count
                    processedCount = 0
                }
                
                for email in emails {
                    let categorization = await ollamaService.categorizeEmail(email.content)
                    
                    if categorization.isJobApplication {
                        var job = Job(
                            companyName: categorization.companyName ?? "Unknown Company",
                            positionName: categorization.positionName ?? "Unknown Position",
                            dateApplied: email.date,
                            status: categorization.detectedStatus ?? .applied
                        )
                        job.emailContent = email.content
                        
                        await MainActor.run {
                            jobStore.addJob(job)
                            processedCount += 1
                        }
                    } else {
                        await MainActor.run {
                            processedCount += 1
                        }
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(JobStore())
        .environmentObject(GmailService())
        .environmentObject(OllamaService())
        .environmentObject(StatusTransitionStore())
}
