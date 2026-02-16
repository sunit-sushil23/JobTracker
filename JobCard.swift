import SwiftUI

struct JobCard: View {
    let job: Job
    let onStatusChange: (Job, JobStatus) -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection
            
            Divider()
                .padding(.horizontal, 4)
            
            detailsSection
            
            if !job.notes.isEmpty {
                notesSection
            }
            
            Spacer()
            
            footerSection
        }
        .padding(12)
        .frame(maxHeight: 200)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .onTapGesture {
            showingDetails = true
        }
        .draggable(job)
        .sheet(isPresented: $showingDetails) {
            JobDetailView(job: job, onStatusChange: onStatusChange)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.companyName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(job.positionName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(job.dateApplied, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Circle()
                    .fill(job.status.color)
                    .frame(width: 8, height: 8)
                
                Text(job.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(job.status.color)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Notes")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text(job.notes.last ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.leading, 16)
        }
    }
    
    private var footerSection: some View {
        HStack {
            Spacer()
            
            Menu {
                ForEach(JobStatus.allCases, id: \.self) { status in
                    if status != job.status {
                        Button(status.rawValue) {
                            onStatusChange(job, status)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

struct JobDetailView: View {
    let job: Job
    let onStatusChange: (Job, JobStatus) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    companySection
                    statusSection
                    datesSection
                    notesSection
                    emailSection
                }
                .padding()
            }
            .navigationTitle("Job Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var companySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Company")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(job.companyName)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(job.positionName)
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Circle()
                    .fill(job.status.color)
                    .frame(width: 12, height: 12)
                
                Text(job.status.rawValue)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(job.status.color)
            }
            
            Menu("Change Status") {
                ForEach(JobStatus.allCases, id: \.self) { status in
                    if status != job.status {
                        Button(status.rawValue) {
                            onStatusChange(job, status)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dates")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Applied:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(job.dateApplied, style: .date)
                        .font(.subheadline)
                }
                
                HStack {
                    Text("Last Updated:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(job.lastUpdated, style: .date)
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            if job.notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(job.notes.reversed(), id: \.self) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note)
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email Content")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let emailContent = job.emailContent {
                ScrollView {
                    Text(emailContent)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .frame(maxHeight: 200)
            } else {
                Text("No email content available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

#Preview {
    JobCard(job: Job(
        companyName: "Apple Inc.",
        positionName: "Senior iOS Developer",
        dateApplied: Date(),
        status: .applied
    )) { _, _ in }
    .frame(width: 280)
}
