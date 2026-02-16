import Foundation

struct EmailCategorization {
    let isJobApplication: Bool
    let companyName: String?
    let positionName: String?
    let detectedStatus: JobStatus?
    let confidence: Double
    let extractedInfo: [String: String]
}

class OllamaServiceImproved: ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var availableModels: [String] = []
    @Published var currentModel = "llama2"
    
    private let baseURL = "http://localhost:11434"
    
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
                    
                    if httpResponse.statusCode == 200, let data = data {
                        self.parseAvailableModels(data)
                    }
                } else {
                    self.isConnected = false
                    self.error = "Invalid response from Ollama"
                }
            }
        }.resume()
    }
    
    private func parseAvailableModels(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                
                availableModels = models.compactMap { model in
                    (model["name"] as? String)?.components(separatedBy: ":").first
                }.unique()
                
                // Prefer newer models if available
                if availableModels.contains("llama3") {
                    currentModel = "llama3"
                } else if availableModels.contains("mistral") {
                    currentModel = "mistral"
                }
                
                print("✅ Found Ollama models: \(availableModels)")
            }
        } catch {
            print("Failed to parse models: \(error)")
        }
    }
    
    func categorizeEmail(_ content: String) async -> EmailCategorization {
        print("🔄 Categorizing email...")
        
        // First try with Ollama if connected
        if isConnected {
            do {
                let categorization = try await categorizeWithOllama(content)
                if categorization.confidence > 0.5 {
                    print("✅ Ollama categorization successful (confidence: \(categorization.confidence))")
                    return categorization
                }
            } catch {
                print("⚠️ Ollama categorization failed: \(error)")
            }
        }
        
        // Fallback to rule-based categorization
        print("🔄 Using fallback rule-based categorization")
        return categorizeWithRules(content)
    }
    
    private func categorizeWithOllama(_ content: String) async throws -> EmailCategorization {
        let prompt = buildImprovedPrompt(for: content)
        let response = try await callOllama(prompt: prompt)
        return parseOllamaResponse(response, content: content)
    }
    
    private func buildImprovedPrompt(for content: String) -> String {
        return """
        You are an expert email analyzer specializing in job application detection and information extraction.

        Analyze the following email and determine if it's related to a job application. Respond ONLY with a valid JSON object.

        {
            "isJobApplication": boolean,
            "companyName": "string or null",
            "positionName": "string or null", 
            "detectedStatus": "Applied|Screening|Technical Interview|Final Interview|Offer|Rejected|Withdrawn|null",
            "confidence": number between 0 and 1,
            "extractedInfo": {
                "reason": "brief explanation of classification",
                "keyPoints": ["array of important information"],
                "senderInfo": "sender name or company if identifiable",
                "applicationType": "new application, interview, rejection, offer, follow-up, or other"
            }
        }

        CLASSIFICATION RULES:
        - isJobApplication = true ONLY for emails about: job applications, interviews, offers, rejections, screening calls, technical assessments
        - isJobApplication = false for: newsletters, marketing, general company updates, spam, unrelated communications
        - Look for keywords: application, interview, offer, position, role, resume, screening, assessment, hiring, recruitment
        - Check sender domain for known job boards (indeed, linkedin, glassdoor, etc.)

        INFORMATION EXTRACTION:
        - Extract company name from signature, sender domain, or email content
        - Extract position title from subject line or email body
        - Determine status from content context:
          * "Applied" -> confirmation emails, application received
          * "Screening" -> phone screen, HR interview, initial conversation  
          * "Technical Interview" -> coding challenges, technical assessments, technical interviews
          * "Final Interview" -> final round, team interviews, executive interviews
          * "Offer" -> job offer, compensation details, offer letter
          * "Rejected" -> rejection emails, not moving forward
          * "Withdrawn" -> if you withdrew from consideration

        Email to analyze:
        \(content.prefix(3000))

        Respond with JSON only:
        """
    }
    
    private func callOllama(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw NSError(domain: "OllamaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let requestBody = [
            "model": currentModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1,  // Lower temperature for more consistent results
                "top_p": 0.9,
                "max_tokens": 1000
            ]
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30.0
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw NSError(domain: "OllamaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Ollama"])
        }
        
        return response
    }
    
    private func parseOllamaResponse(_ response: String, content: String) -> EmailCategorization {
        // Extract JSON from response (in case there's extra text)
        let jsonPattern = #"\{[\s\S]*\}"#
        let regex = try? NSRegularExpression(pattern: jsonPattern)
        let range = NSRange(location: 0, length: response.utf16.count)
        
        guard let jsonMatch = regex?.firstMatch(in: response, options: [], range: range),
              let jsonRange = Range(jsonMatch.range, in: response),
              let jsonData = response[jsonRange].data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            
            print("⚠️ Failed to parse Ollama JSON response, using fallback")
            return categorizeWithRules(content)
        }
        
        let isJobApplication = json["isJobApplication"] as? Bool ?? false
        let companyName = json["companyName"] as? String
        let positionName = json["positionName"] as? String
        let confidence = json["confidence"] as? Double ?? 0.0
        let extractedInfo = json["extractedInfo"] as? [String: Any] ?? [:]
        
        var detectedStatus: JobStatus?
        if let statusString = json["detectedStatus"] as? String {
            detectedStatus = parseJobStatus(statusString)
        }
        
        // Use fallback extraction if AI failed to extract
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
    
    private func categorizeWithRules(_ content: String) -> EmailCategorization {
        let lowerContent = content.lowercased()
        
        // Job application keywords
        let jobKeywords = [
            "application", "applied", "resume", "cover letter", "interview", "screening",
            "technical", "assessment", "offer", "position", "role", "hiring", "recruitment",
            "job", "career", "opportunity", "candidate", "selection", "qualified"
        ]
        
        let hasJobKeywords = jobKeywords.contains { lowerContent.contains($0) }
        
        // Rejection keywords
        let rejectionKeywords = ["rejected", "not selected", "unsuccessful", "moving forward", "selected another candidate"]
        let isRejection = rejectionKeywords.contains { lowerContent.contains($0) }
        
        // Offer keywords  
        let offerKeywords = ["offer", "compensation", "salary", "start date", "employment offer"]
        let isOffer = offerKeywords.contains { lowerContent.contains($0) }
        
        // Interview keywords
        let interviewKeywords = ["interview", "screening call", "technical assessment", "phone screen", "on-site"]
        let isInterview = interviewKeywords.contains { lowerContent.contains($0) }
        
        let isJobApplication = hasJobKeywords && !isNewsletter(content)
        
        var detectedStatus: JobStatus?
        if isJobApplication {
            if isRejection {
                detectedStatus = .rejected
            } else if isOffer {
                detectedStatus = .offer
            } else if isInterview {
                detectedStatus = lowerContent.contains("technical") ? .technical : .screening
            } else {
                detectedStatus = .applied
            }
        }
        
        let confidence = calculateRuleConfidence(content, isJobApplication: isJobApplication)
        
        return EmailCategorization(
            isJobApplication: isJobApplication,
            companyName: extractCompanyName(from: content),
            positionName: extractPositionName(from: content),
            detectedStatus: detectedStatus,
            confidence: confidence,
            extractedInfo: [
                "method": "rule-based",
                "reason": isJobApplication ? "Contains job-related keywords" : "No job-related content detected"
            ]
        )
    }
    
    private func isNewsletter(_ content: String) -> Bool {
        let lowerContent = content.lowercased()
        let newsletterKeywords = [
            "unsubscribe", "newsletter", "marketing", "promotion", "sale", "discount",
            "weekly digest", "update", "announcement", "blog post"
        ]
        return newsletterKeywords.contains { lowerContent.contains($0) }
    }
    
    private func calculateRuleConfidence(_ content: String, isJobApplication: Bool) -> Double {
        if !isJobApplication {
            return 0.8 // High confidence for non-job emails
        }
        
        let lowerContent = content.lowercased()
        var confidence = 0.5 // Base confidence
        
        // Increase confidence based on specific indicators
        if lowerContent.contains("application received") || lowerContent.contains("thank you for applying") {
            confidence += 0.3
        }
        if lowerContent.contains("interview") {
            confidence += 0.2
        }
        if lowerContent.contains("offer") {
            confidence += 0.3
        }
        
        return min(confidence, 1.0)
    }
    
    private func parseJobStatus(_ statusString: String) -> JobStatus? {
        let lowerStatus = statusString.lowercased()
        
        switch lowerStatus {
        case "applied": return .applied
        case "screening": return .screening  
        case "technical interview": return .technical
        case "final interview": return .final
        case "offer": return .offer
        case "rejected": return .rejected
        case "withdrawn": return .withdrawn
        default: return nil
        }
    }
    
    private func extractCompanyName(from content: String) -> String? {
        // Try to extract from sender domain
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines.prefix(10) { // Check first 10 lines
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for email addresses
            if trimmedLine.contains("@") && trimmedLine.contains(".") {
                if let atIndex = trimmedLine.range(of: "@") {
                    let domainPart = String(trimmedLine[atIndex.upperBound...])
                        .components(separatedBy: " ").first?
                        .components(separatedBy: "<").first?
                        .replacingOccurrences(of: ">", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    
                    if let domain = domainPart, domain.contains(".") {
                        // Extract company name from domain
                        let domainParts = domain.components(separatedBy: ".")
                        if domainParts.count >= 2 {
                            let companyName = domainParts[domainParts.count - 2]
                                .replacingOccurrences(of: "mail", with: "")
                                .replacingOccurrences(of: "noreply", with: "")
                                .capitalized
                            
                            if companyName.count > 2 {
                                return companyName
                            }
                        }
                    }
                }
            }
        }
        
        // Try signature extraction
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.lowercased().contains("regards") ||
               trimmedLine.lowercased().contains("sincerely") ||
               trimmedLine.lowercased().contains("best") ||
               trimmedLine.lowercased().contains("thanks") {
                
                // Look at next few lines for company name
                for i in (index + 1)..<min(index + 5, lines.count) {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !nextLine.isEmpty && nextLine.count > 3 && nextLine.count < 60 {
                        // Skip personal names and emails
                        if !nextLine.contains("@") && !nextLine.lowercased().contains("http") {
                            return nextLine
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractPositionName(from content: String) -> String? {
        let commonPositions = [
            "software engineer", "senior software engineer", "junior developer", "full stack developer",
            "frontend developer", "backend developer", "mobile developer", "devops engineer",
            "product manager", "project manager", "program manager", "technical lead",
            "data scientist", "data analyst", "machine learning engineer", "ux designer",
            "ui designer", "product designer", "qa engineer", "systems engineer",
            "solutions architect", "cloud engineer", "security engineer", "platform engineer"
        ]
        
        let lowerContent = content.lowercased()
        
        // Look for exact matches first
        for position in commonPositions {
            if lowerContent.contains(position) {
                // Extract the full context around the match
                if let range = lowerContent.range(of: position) {
                    let startIndex = max(lowerContent.startIndex, lowerContent.index(range.lowerBound, offsetBy: -50))
                    let endIndex = min(lowerContent.endIndex, lowerContent.index(range.upperBound, offsetBy: 50))
                    let context = String(lowerContent[startIndex..<endIndex])
                    
                    // Try to extract a cleaner position title
                    let words = context.components(separatedBy: .whitespacesAndNewlines)
                    for (index, word) in words.enumerated() {
                        if word.lowercased().contains(position.components(separatedBy: " ").first!) {
                            // Get surrounding words for better context
                            let startIdx = max(0, index - 2)
                            let endIdx = min(words.count, index + 4)
                            let positionWords = words[startIdx..<endIdx]
                            
                            let extractedPosition = positionWords.joined(separator: " ")
                                .components(separatedBy: ".")
                                .first?
                                .components(separatedBy: ",")
                                .first?
                                .trimmingCharacters(in: .punctuationCharacters)
                                .capitalized
                            
                            if let position = extractedPosition, position.count > 10 && position.count < 100 {
                                return position
                            }
                        }
                    }
                }
                
                // Fallback to the matched position
                return position.capitalized
            }
        }
        
        // Try to extract from subject line
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for position indicators
            if trimmedLine.lowercased().contains("position:") ||
               trimmedLine.lowercased().contains("role:") ||
               trimmedLine.lowercased().contains("job:") {
                
                let parts = trimmedLine.components(separatedBy: ":")
                if parts.count > 1 {
                    let position = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if position.count > 5 && position.count < 100 {
                        return position
                    }
                }
            }
        }
        
        return nil
    }
    
    func updateModel(_ modelName: String) {
        currentModel = modelName
        checkConnection()
    }
    
    func testCategorization() {
        let testEmails = [
            """
            Subject: Application Received - Software Engineer Position
            
            Dear Candidate,
            
            Thank you for your interest in the Software Engineer position at TechCorp. 
            We have received your application and will review it carefully.
            
            Best regards,
            TechCorp HR Team
            """,
            
            """
            Subject: Interview Invitation - Senior Developer
            
            Hi there,
            
            We'd like to schedule a technical interview for the Senior Developer position.
            Are you available next week?
            
            Thanks,
            Acme Inc
            """,
            
            """
            Subject: Weekly Newsletter - Tech Updates
            
            Check out our latest tech articles and updates!
            
            Unsubscribe | Preferences
            """
        ]
        
        for (index, email) in testEmails.enumerated() {
            print("\n🧪 Test Email \(index + 1):")
            Task {
                let result = await categorizeEmail(email)
                print("📝 Result: \(result.isJobApplication ? "Job Application" : "Not Job Application")")
                print("🏢 Company: \(result.companyName ?? "Unknown")")
                print("💼 Position: \(result.positionName ?? "Unknown")")
                print("📊 Status: \(result.detectedStatus?.rawValue ?? "Unknown")")
                print("🎯 Confidence: \(result.confidence)")
            }
        }
    }
}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        return Array(Set(self))
    }
}
