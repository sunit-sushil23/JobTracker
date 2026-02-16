import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum JobStatus: String, CaseIterable, Codable {
    case applied = "Applied"
    case screening = "Screening"
    case technical = "Technical Interview"
    case final = "Final Interview"
    case offer = "Offer"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
    
    var color: Color {
        switch self {
        case .applied: return .blue
        case .screening: return .orange
        case .technical: return .purple
        case .final: return .green
        case .offer: return .mint
        case .rejected: return .red
        case .withdrawn: return .gray
        }
    }
}

struct Job: Identifiable, Codable, Transferable {
    let id = UUID()
    var companyName: String
    var positionName: String
    var dateApplied: Date
    var status: JobStatus
    var notes: [String] = []
    var emailContent: String?
    var lastUpdated: Date = Date()
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
    
    init(companyName: String, positionName: String, dateApplied: Date, status: JobStatus = .applied) {
        self.companyName = companyName
        self.positionName = positionName
        self.dateApplied = dateApplied
        self.status = status
    }
}

class JobStore: ObservableObject {
    @Published var jobs: [Job] = []
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var jobsFileURL: URL {
        documentsURL.appendingPathComponent("jobs.json")
    }
    
    init() {
        loadJobs()
    }
    
    func addJob(_ job: Job) {
        jobs.append(job)
        saveJobs()
    }
    
    func updateJob(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            saveJobs()
        }
    }
    
    func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        saveJobs()
    }
    
    func moveJob(_ job: Job, to newStatus: JobStatus, with notes: String? = nil) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index].status = newStatus
            jobs[index].lastUpdated = Date()
            if let notes = notes, !notes.isEmpty {
                jobs[index].notes.append(notes)
            }
            saveJobs()
        }
    }
    
    func getJobsByStatus(_ status: JobStatus) -> [Job] {
        return jobs.filter { $0.status == status }.sorted { $0.dateApplied > $1.dateApplied }
    }
    
    private func saveJobs() {
        do {
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: jobsFileURL)
        } catch {
            print("Failed to save jobs: \(error)")
        }
    }
    
    private func loadJobs() {
        do {
            let data = try Data(contentsOf: jobsFileURL)
            jobs = try JSONDecoder().decode([Job].self, from: data)
        } catch {
            print("Failed to load jobs: \(error)")
            jobs = []
        }
    }
}

struct StatusTransitionQuestion: Codable {
    let fromStatus: JobStatus
    let toStatus: JobStatus
    let question: String
    let isRequired: Bool
}

class StatusTransitionStore: ObservableObject {
    @Published var questions: [StatusTransitionQuestion] = []
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var questionsFileURL: URL {
        documentsURL.appendingPathComponent("transition_questions.json")
    }
    
    init() {
        loadDefaultQuestions()
        loadQuestions()
    }
    
    func getQuestion(for fromStatus: JobStatus, to: JobStatus) -> StatusTransitionQuestion? {
        return questions.first { $0.fromStatus == fromStatus && $0.toStatus == to }
    }
    
    func addQuestion(_ question: StatusTransitionQuestion) {
        questions.append(question)
        saveQuestions()
    }
    
    private func loadDefaultQuestions() {
        questions = [
            StatusTransitionQuestion(fromStatus: .applied, toStatus: .screening, question: "What was the initial screening about?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .screening, toStatus: .technical, question: "What technical topics were discussed?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .technical, toStatus: .final, question: "Who did you speak with in the final round?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .final, toStatus: .offer, question: "What are the offer details (salary, benefits, start date)?", isRequired: true),
            StatusTransitionQuestion(fromStatus: .applied, toStatus: .rejected, question: "What was the reason for rejection?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .screening, toStatus: .rejected, question: "What was the reason for rejection?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .technical, toStatus: .rejected, question: "What was the reason for rejection?", isRequired: false),
            StatusTransitionQuestion(fromStatus: .final, toStatus: .rejected, question: "What was the reason for rejection?", isRequired: false),
        ]
    }
    
    private func saveQuestions() {
        do {
            let data = try JSONEncoder().encode(questions)
            try data.write(to: questionsFileURL)
        } catch {
            print("Failed to save questions: \(error)")
        }
    }
    
    private func loadQuestions() {
        do {
            let data = try Data(contentsOf: questionsFileURL)
            questions = try JSONDecoder().decode([StatusTransitionQuestion].self, from: data)
        } catch {
            print("Failed to load questions: \(error)")
        }
    }
}
