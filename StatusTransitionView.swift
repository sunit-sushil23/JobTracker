import SwiftUI

struct StatusTransitionView: View {
    let job: Job
    let targetStatus: JobStatus
    let onComplete: (Job, String?) -> Void
    
    @EnvironmentObject var transitionStore: StatusTransitionStore
    @State private var answer = ""
    @State private var isCompleting = false
    
    private var transitionQuestion: StatusTransitionQuestion? {
        transitionStore.getQuestion(for: job.status, to: targetStatus)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if let question = transitionQuestion {
                questionSection(question)
            } else {
                noQuestionSection
            }
            
            Spacer()
            
            actionButtons
        }
        .padding()
        .frame(width: 450, height: 350)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(job.status.color)
                    .frame(width: 16, height: 16)
                
                Text(job.status.rawValue)
                    .font(.headline)
                    .foregroundColor(job.status.color)
                
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(targetStatus.color)
                    .frame(width: 16, height: 16)
                
                Text(targetStatus.rawValue)
                    .font(.headline)
                    .foregroundColor(targetStatus.color)
            }
            
            VStack(spacing: 4) {
                Text(job.companyName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(job.positionName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func questionSection(_ question: StatusTransitionQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: question.isRequired ? "exclamationmark.circle.fill" : "questionmark.circle")
                    .foregroundColor(question.isRequired ? .orange : .blue)
                
                Text(question.isRequired ? "Required Information" : "Optional Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(question.question)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $answer)
                .frame(minHeight: 80)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var noQuestionSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text("Ready to move to \(targetStatus.rawValue)")
                .font(.headline)
            
            Text("No additional information required for this transition.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                onComplete(job, nil)
            }
            .keyboardShortcut(.escape)
            
            Spacer()
            
            Button("Move to \(targetStatus.rawValue)") {
                isCompleting = true
                let notes = answer.isEmpty ? nil : answer
                onComplete(job, notes)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isCompleting ||
                (transitionQuestion?.isRequired == true && answer.isEmpty)
            )
        }
    }
}

#Preview {
    StatusTransitionView(
        job: Job(
            companyName: "Apple Inc.",
            positionName: "Senior iOS Developer",
            dateApplied: Date(),
            status: .applied
        ),
        targetStatus: .screening
    ) { _, _ in }
    .environmentObject(StatusTransitionStore())
}
