import SwiftUI

struct AddJobView: View {
    @EnvironmentObject var jobStore: JobStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var companyName = ""
    @State private var positionName = ""
    @State private var dateApplied = Date()
    @State private var selectedStatus = JobStatus.applied
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Company Information")) {
                    TextField("Company Name", text: $companyName)
                    TextField("Position Name", text: $positionName)
                }
                
                Section(header: Text("Application Details")) {
                    DatePicker("Date Applied", selection: $dateApplied, displayedComponents: .date)
                    
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(JobStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue)
                            }
                            .tag(status)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addJob()
                    }
                    .disabled(companyName.isEmpty || positionName.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func addJob() {
        let job = Job(
            companyName: companyName,
            positionName: positionName,
            dateApplied: dateApplied,
            status: selectedStatus
        )
        
        if !notes.isEmpty {
            var updatedJob = job
            updatedJob.notes.append(notes)
            jobStore.addJob(updatedJob)
        } else {
            jobStore.addJob(job)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddJobView()
        .environmentObject(JobStore())
}
