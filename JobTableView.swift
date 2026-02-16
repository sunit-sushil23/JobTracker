import SwiftUI

struct JobTableView: View {
    @EnvironmentObject var jobStore: JobStore
    @State private var selectedJob: Job?
    @State private var showingStatusTransition = false
    @State private var targetStatus: JobStatus?
    @State private var sortOrder = [KeyPathComparator(\Job.dateApplied, order: .reverse)]
    
    var body: some View {
        Table(jobStore.jobs.sorted(using: sortOrder)) {
            TableColumn("Company") { job in
                Text(job.companyName)
                    .fontWeight(.medium)
            }
            
            TableColumn("Position") { job in
                Text(job.positionName)
                    .foregroundColor(.secondary)
            }
            
            TableColumn("Date Applied") { job in
                Text(job.dateApplied, style: .date)
                    .font(.caption)
            }
            
            TableColumn("Status") { job in
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
            
            TableColumn("Actions") { job in
                Menu {
                    ForEach(JobStatus.allCases, id: \.self) { status in
                        if status != job.status {
                            Button(status.rawValue) {
                                selectedJob = job
                                targetStatus = status
                                showingStatusTransition = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .tableStyle(.bordered)
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

#Preview {
    JobTableView()
        .environmentObject(JobStore())
        .environmentObject(StatusTransitionStore())
}
