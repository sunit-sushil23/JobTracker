import Foundation

// Test email categorization without Ollama dependency
class EmailCategorizationTest {
    
    func runCategorizationTests() {
        print("🧪 Starting Email Categorization Tests...")
        print("=" * 50)
        
        let testEmails = [
            (
                email: """
                Subject: Application Received - Software Engineer Position
                
                Dear Candidate,
                
                Thank you for your interest in the Software Engineer position at TechCorp. 
                We have received your application and will review it carefully. Our team will 
                get back to you within 5-7 business days.
                
                Best regards,
                TechCorp HR Team
                hr@techcorp.com
                """,
                expectedIsJobApplication: true,
                expectedCompany: "TechCorp",
                expectedPosition: "Software Engineer"
            ),
            
            (
                email: """
                Subject: Technical Interview - Senior Developer Role
                
                Hi there,
                
                We'd like to schedule a technical interview for the Senior Developer position. 
                The interview will include a coding challenge and system design discussion.
                
                Are you available next Tuesday or Wednesday?
                
                Thanks,
                Sarah Johnson
                Acme Inc. Recruiting
                sarah@acme.com
                """,
                expectedIsJobApplication: true,
                expectedCompany: "Acme Inc",
                expectedPosition: "Senior Developer"
            ),
            
            (
                email: """
                Subject: Job Offer - Product Manager
                
                Congratulations! We're pleased to offer you the Product Manager position at StartupXYZ.
                
                Offer Details:
                - Salary: $120,000
                - Start Date: Monday, March 15, 2024
                - Location: San Francisco, CA (Hybrid)
                
                Please review and sign the offer letter by Friday.
                
                Best regards,
                Michael Chen
                VP of Engineering
                StartupXYZ
                """,
                expectedIsJobApplication: true,
                expectedCompany: "StartupXYZ",
                expectedPosition: "Product Manager"
            ),
            
            (
                email: """
                Subject: Your Weekly Tech Newsletter
                
                Check out this week's top tech stories and job market insights!
                
                1. AI Trends in 2024
                2. Remote Work Statistics
                3. Startup Funding Roundup
                
                Unsubscribe | Preferences | View in Browser
                """,
                expectedIsJobApplication: false,
                expectedCompany: nil,
                expectedPosition: nil
            ),
            
            (
                email: """
                Subject: Rejection - Your Application
                
                Dear Applicant,
                
                Thank you for your interest in the Data Scientist position at DataCorp.
                After careful consideration, we have decided to move forward with other candidates 
                whose qualifications more closely match our requirements.
                
                We wish you the best in your job search.
                
                Regards,
                DataCorp HR
                """,
                expectedIsJobApplication: true,
                expectedCompany: "DataCorp",
                expectedPosition: "Data Scientist"
            )
        ]
        
        for (index, testData) in testEmails.enumerated() {
            print("\n🧪 Test Email \(index + 1):")
            
            let categorization = categorizeWithRules(testData.email)
            
            print("📧 Subject: \(extractSubject(from: testData.email))")
            print("🔍 Is Job Application: \(categorization.isJobApplication) (Expected: \(testData.expectedIsJobApplication))")
            print("🏢 Company: \(categorization.companyName ?? "Unknown") (Expected: \(testData.expectedCompany ?? "Unknown"))")
            print("💼 Position: \(categorization.positionName ?? "Unknown") (Expected: \(testData.expectedPosition ?? "Unknown"))")
            print("📊 Status: \(categorization.detectedStatus?.rawValue ?? "Unknown")")
            print("🎯 Confidence: \(String(format: "%.2f", categorization.confidence))")
            
            // Validate results
            var passed = true
            if categorization.isJobApplication != testData.expectedIsJobApplication {
                print("❌ FAILED: Job application detection mismatch")
                passed = false
            }
            
            if let expectedCompany = testData.expectedCompany,
               let actualCompany = categorization.companyName,
               !actualCompany.lowercased().contains(expectedCompany.lowercased()) {
                print("❌ FAILED: Company name mismatch")
                passed = false
            }
            
            if let expectedPosition = testData.expectedPosition,
               let actualPosition = categorization.positionName,
               !actualPosition.lowercased().contains(expectedPosition.lowercased()) {
                print("❌ FAILED: Position name mismatch")
                passed = false
            }
            
            if passed {
                print("✅ PASSED")
            } else {
                print("❌ FAILED")
            }
        }
        
        print("\n" + "=" * 50)
        print("✅ Email categorization tests completed!")
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
    
    private func extractSubject(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(3) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.lowercased().hasPrefix("subject:") {
                return trimmedLine.replacingOccurrences(of: "subject:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "No Subject"
    }
}

// Mock JobStatus enum for testing
enum JobStatus: String, CaseIterable {
    case applied = "Applied"
    case screening = "Screening"
    case technical = "Technical Interview"
    case final = "Final Interview"
    case offer = "Offer"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
}

// Mock EmailCategorization struct for testing
struct EmailCategorization {
    let isJobApplication: Bool
    let companyName: String?
    let positionName: String?
    let detectedStatus: JobStatus?
    let confidence: Double
    let extractedInfo: [String: String]
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Main test execution
print("🧪 Email Categorization Test")
print("📝 Testing rule-based email categorization without Ollama dependency")
print()

let tester = EmailCategorizationTest()
tester.runCategorizationTests()
