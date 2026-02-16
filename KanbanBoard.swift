import SwiftUI

struct KanbanBoard: View {
    @EnvironmentObject var jobStore: JobStore
    @State private var draggedJob: Job?
    @State private var showingStatusTransition = false
    @State private var selectedJob: Job?
    @State private var targetStatus: JobStatus?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(JobStatus.allCases, id: \.self) { status in
                    statusColumn(status)
                        .dropDestination(for: Job.self) { jobs, location in
                            guard let job = jobs.first else { return false }
                            
                            if job.status != status {
                                selectedJob = job
                                targetStatus = status
                                showingStatusTransition = true
                            }
                            return true
                        }
                }
            }
            .padding(.horizontal, 16)
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

#Preview {
    KanbanBoard()
        .environmentObject(JobStore())
        .frame(height: 600)
}
