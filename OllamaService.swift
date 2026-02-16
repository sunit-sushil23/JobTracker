import Foundation

struct EmailCategorization {
    let isJobApplication: Bool
    let companyName: String?
    let positionName: String?
    let detectedStatus: JobStatus?
    let confidence: Double
    let extractedInfo: [String: String]
}

class OllamaService: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "http://localhost:11434"
    private var modelName = "llama2" // Change to your preferred model
    
    init() {
        checkConnection()
    }
    
    func checkConnection() {
        isLoading = true
        
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            error = "Invalid Ollama URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    self.error = "Failed to connect to Ollama: \(error.localizedDescription)"
                    self.isConnected = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self.isConnected = httpResponse.statusCode == 200
                } else {
                    self.isConnected = false
                    self.error = "Invalid response from Ollama"
                }
            }
        }.resume()
    }
    
    func categorizeEmail(_ content: String) async -> EmailCategorization {
        guard isConnected else {
            return EmailCategorization(
                isJobApplication: false,
                companyName: nil,
                positionName: nil,
                detectedStatus: nil,
                confidence: 0.0,
                extractedInfo: [:]
            )
        }
        
        let prompt = buildPrompt(for: content)
        
        do {
            let response = try await callOllama(prompt: prompt)
            return parseResponse(response, content: content)
        } catch {
            await MainActor.run {
                self.error = "Failed to categorize email: \(error.localizedDescription)"
            }
            return EmailCategorization(
                isJobApplication: false,
                companyName: nil,
                positionName: nil,
                detectedStatus: nil,
                confidence: 0.0,
                extractedInfo: [:]
            )
        }
    }
    
    private func buildPrompt(for content: String) -> String {
        return """
        You are an AI assistant that analyzes emails to determine if they are job application related and extracts relevant information.

        Analyze the following email and respond in JSON format with the following structure:
        {
            "isJobApplication": boolean,
            "companyName": "string or null",
            "positionName": "string or null",
            "detectedStatus": "Applied|Screening|Technical Interview|Final Interview|Offer|Rejected|Withdrawn|null",
            "confidence": number between 0 and 1,
            "extractedInfo": {
                "reason": "brief explanation of why this is or isn't a job application",
                "keyPoints": ["array of key points from the email"]
            }
        }

        Rules:
        - Set isJobApplication to true only if the email is clearly about a job application, interview, offer, or rejection
        - Extract company name from the email content, signature, or sender information
        - Extract position title from the email content
        - Determine the current status based on email content (applied, screening, interview, offer, rejected, etc.)
        - Set confidence based on how certain you are about the classification
        - If it's not a job application, set isJobApplication to false and other fields to null

        Email content:
        \(content.prefix(2000))

        Respond only with valid JSON:
        """
    }
    
    private func callOllama(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw NSError(domain: "OllamaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let requestBody = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw NSError(domain: "OllamaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Ollama"])
        }
        
        return response
    }
    
    private func parseResponse(_ response: String, content: String) -> EmailCategorization {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return EmailCategorization(
                isJobApplication: false,
                companyName: nil,
                positionName: nil,
                detectedStatus: nil,
                confidence: 0.0,
                extractedInfo: ["error": "Failed to parse Ollama response"]
            )
        }
        
        let isJobApplication = json["isJobApplication"] as? Bool ?? false
        let companyName = json["companyName"] as? String
        let positionName = json["positionName"] as? String
        let confidence = json["confidence"] as? Double ?? 0.0
        let extractedInfo = json["extractedInfo"] as? [String: Any] ?? [:]
        
        var detectedStatus: JobStatus?
        if let statusString = json["detectedStatus"] as? String {
            detectedStatus = JobStatus.allCases.first { $0.rawValue.lowercased() == statusString.lowercased() }
        }
        
        // Fallback extraction if Ollama fails to extract
        let fallbackCompany = companyName ?? extractCompanyName(from: content)
        let fallbackPosition = positionName ?? extractPositionName(from: content)
        
        return EmailCategorization(
            isJobApplication: isJobApplication,
            companyName: fallbackCompany,
            positionName: fallbackPosition,
            detectedStatus: detectedStatus,
            confidence: confidence,
            extractedInfo: extractedInfo as? [String: String] ?? [:]
        )
    }
    
    private func extractCompanyName(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        
        // Look for common patterns
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for company name in signature
            if trimmedLine.lowercased().contains("regards") ||
               trimmedLine.lowercased().contains("sincerely") ||
               trimmedLine.lowercased().contains("best") {
                // Look at the next few lines for company name
                if let index = lines.firstIndex(of: line) {
                    for i in (index + 1)..<min(index + 4, lines.count) {
                        let nextLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !nextLine.isEmpty && nextLine.count > 3 && nextLine.count < 50 {
                            return nextLine
                        }
                    }
                }
            }
        }
        
        // Try to extract from sender information or first few lines
        let firstLines = Array(lines.prefix(5))
        for line in firstLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.contains("@") && trimmedLine.contains(".") {
                // This looks like an email, extract domain as potential company
                if let atIndex = trimmedLine.range(of: "@") {
                    let domain = String(trimmedLine[atIndex.upperBound...])
                        .components(separatedBy: " ").first?
                        .components(separatedBy: "<").first?
                        .replacingOccurrences(of: ">", with: "")
                    
                    if let domain = domain, domain.contains(".") {
                        let companyName = domain.components(separatedBy: ".")
                            .first?
                            .capitalized
                        return companyName
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractPositionName(from content: String) -> String? {
        let commonPositions = [
            "software engineer", "developer", "manager", "director", "analyst",
            "designer", "consultant", "specialist", "coordinator", "assistant",
            "engineer", "architect", "lead", "senior", "junior", "intern"
        ]
        
        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for (index, word) in words.enumerated() {
            if commonPositions.contains(word) {
                // Look for surrounding words to form a position title
                let startIndex = max(0, index - 2)
                let endIndex = min(words.count, index + 3)
                let positionWords = words[startIndex..<endIndex]
                
                let position = positionWords.joined(separator: " ")
                    .components(separatedBy: ".")
                    .first?
                    .trimmingCharacters(in: .punctuationCharacters)
                
                if let position = position, position.count > 5 && position.count < 100 {
                    return position.capitalized
                }
            }
        }
        
        return nil
    }
    
    func updateModel(_ modelName: String) {
        self.modelName = modelName
        checkConnection()
    }
}
