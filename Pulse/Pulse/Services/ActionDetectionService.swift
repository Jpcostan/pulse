//
//  ActionDetectionService.swift
//  Pulse
//

import Foundation
import NaturalLanguage
import CoreData
import Combine
import OSLog

@MainActor
final class ActionDetectionService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentStep: String = ""

    // MARK: - Action Patterns

    /// Patterns that indicate an action item.
    /// `requiresTaskContext`: when true, the sentence must also contain a task verb, task noun,
    /// or time reference to be considered an action. This prevents poems/narrative from matching.
    private let actionPatterns: [(pattern: String, confidence: Double, requiresTaskContext: Bool)] = [
        // First person commitments — generic, need task context
        ("i('ll| will) ", 0.90, true),
        ("i need to ", 0.92, true),
        ("i have to ", 0.90, true),
        ("i'm going to ", 0.88, true),
        ("i am going to ", 0.88, true),
        ("i should ", 0.85, true),
        ("i must ", 0.90, true),

        // We/team commitments — generic, need task context
        ("we('ll| will) ", 0.88, true),
        ("we need to ", 0.90, true),
        ("we have to ", 0.88, true),
        ("we should ", 0.85, true),
        ("we're going to ", 0.86, true),
        ("we are going to ", 0.86, true),
        ("let's ", 0.82, true),

        // Requests/assignments — generic, need task context
        ("can you ", 0.80, true),
        ("could you ", 0.78, true),
        ("please ", 0.75, true),
        ("you need to ", 0.85, true),
        ("you should ", 0.82, true),

        // Reminders — specific enough (except bare "remember")
        ("don't forget to ", 0.92, false),
        ("don't forget ", 0.88, false),
        ("dont forget to ", 0.92, false),
        ("dont forget ", 0.88, false),
        ("do not forget to ", 0.92, false),
        ("do not forget ", 0.88, false),
        ("remember to ", 0.90, false),
        ("remember ", 0.82, true),  // "remember" alone is broad (poems: "I remember the...")
        ("make sure to ", 0.88, false),
        ("make sure ", 0.84, false),
        ("be sure to ", 0.88, false),
        ("be sure ", 0.84, false),

        // Meeting/appointment mentions — specific
        ("meeting (on |at |this |next |)", 0.75, false),
        ("appointment (on |at |this |next |)", 0.75, false),
        ("call (on |at |this |next |with )", 0.75, false),

        // Action verbs at start (imperative mood) — specific
        ("^send ", 0.80, false),
        ("^schedule ", 0.85, false),
        ("^review ", 0.82, false),
        ("^update ", 0.80, false),
        ("^create ", 0.80, false),
        ("^prepare ", 0.82, false),
        ("^complete ", 0.85, false),
        ("^finish ", 0.85, false),
        ("^follow up ", 0.88, false),
        ("^check ", 0.78, false),
        ("^contact ", 0.82, false),
        ("^call ", 0.80, false),
        ("^email ", 0.82, false),
        ("^set up ", 0.82, false),
        ("^organize ", 0.80, false),
        ("^book ", 0.82, false),
        ("^arrange ", 0.80, false),
        ("^submit ", 0.85, false),
        ("^share ", 0.78, false),

        // Intent phrases — generic, need task context
        ("i plan to ", 0.88, true),
        ("i intend to ", 0.88, true),
        ("my plan is to ", 0.88, true),
        ("the plan is to ", 0.86, true),
        ("the goal is to ", 0.86, true),

        // Task markers — specific
        ("action item ", 0.92, false),
        ("todo ", 0.90, false),
        ("to-do ", 0.90, false),

        // Phrasal verbs — specific
        ("take care of ", 0.85, false),
        ("handle ", 0.82, false),
        ("deal with ", 0.82, false),
        ("reach out to ", 0.88, false),
        ("get back to ", 0.85, false),
        ("circle back ", 0.85, false),
        ("follow up on ", 0.88, false),

        // Deadline indicators — specific
        ("deadline is ", 0.90, false),
        ("due by ", 0.90, false),
        ("due at ", 0.90, false),
        ("due date ", 0.88, false),
        ("due (today|tonight|tomorrow|this|next)", 0.88, false),

        // Needs/requirements — generic, need task context
        ("needs to be ", 0.85, true),
        ("has to be ", 0.85, true),
        ("must be ", 0.88, true),
        ("should be ", 0.80, true),

        // "I have a [task noun]" — specific (task noun is in the pattern itself)
        ("i have (a |an |)(meeting|appointment|deadline|assignment|homework|exam|test|interview|presentation) ", 0.80, false),
        ("i('ve| have) got (a |an |)(meeting|appointment|deadline|assignment|homework|exam|test|interview|presentation) ", 0.80, false),
        ("there('s| is) (a |an |)(meeting|appointment|deadline|assignment|homework) ", 0.78, false),
    ]

    // MARK: - Task Context Words

    /// Verbs that indicate a concrete task (not poetic/narrative)
    private let taskVerbs: Set<String> = [
        "send", "email", "call", "schedule", "review", "submit", "prepare",
        "create", "update", "finish", "complete", "organize", "book", "arrange",
        "contact", "share", "write", "draft", "file", "order", "purchase", "buy",
        "fix", "deliver", "pay", "register", "sign", "approve", "confirm",
        "cancel", "reschedule", "assign", "delegate", "notify", "inform",
        "print", "upload", "download", "install", "deploy", "test", "clean",
        "coordinate", "plan", "implement", "build", "design", "investigate",
        "research", "analyze", "document", "train", "hire", "interview",
        "present", "demo", "ship", "release", "launch", "publish", "post",
        "edit", "proofread", "grade", "study", "practice", "rehearse",
        "address", "resolve", "escalate", "meet", "attend", "discuss",
        "pick up", "drop off",
    ]

    /// Nouns that indicate a work/task context
    private let taskNouns: Set<String> = [
        "email", "report", "meeting", "deadline", "document", "presentation",
        "proposal", "budget", "project", "task", "assignment", "homework",
        "exam", "test", "appointment", "interview", "contract", "ticket",
        "issue", "request", "payment", "bill", "package", "invoice",
        "agenda", "calendar", "spreadsheet", "server", "client", "customer",
        "office", "work", "class", "course", "lecture", "conference",
    ]

    /// Time indicators that suggest a concrete deadline/schedule
    private let timeIndicators: Set<String> = [
        "tomorrow", "today", "tonight", "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday", "sunday", "next week", "next month",
        "this week", "this month", "deadline", "due", "asap", "eod",
        "end of day", "end of week", "morning", "afternoon", "evening",
    ]

    // MARK: - Date Keywords

    private let relativeDateKeywords: [String: Int] = [
        "today": 0,
        "tonight": 0,
        "tomorrow": 1,
        "day after tomorrow": 2,
        "next week": 7,
        "next monday": -1, // Special handling
        "next tuesday": -1,
        "next wednesday": -1,
        "next thursday": -1,
        "next friday": -1,
        "next saturday": -1,
        "next sunday": -1,
        "this week": 3,
        "end of day": 0,
        "end of week": -2, // Special handling for Friday
        "by friday": -3, // Special handling
        "by monday": -4,
        // Standalone weekday names (will find the next occurrence)
        "on monday": -1,
        "on tuesday": -1,
        "on wednesday": -1,
        "on thursday": -1,
        "on friday": -1,
        "on saturday": -1,
        "on sunday": -1,
    ]

    /// Map spelled-out numbers to digits for time parsing
    private let spelledNumbers: [String: String] = [
        "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
        "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
        "eleven": "11", "twelve": "12", "noon": "12", "midnight": "0",
    ]

    // MARK: - Public Methods

    /// Detect action items from transcript text
    func detectActions(
        from transcriptText: String,
        meeting: Meeting,
        context: NSManagedObjectContext
    ) async throws -> Int {
        isProcessing = true
        progress = 0
        currentStep = "Analyzing transcript..."

        defer {
            isProcessing = false
        }

        // Step 1: Segment into sentences
        progress = 0.2
        currentStep = "Segmenting sentences..."
        let sentences = segmentSentences(from: transcriptText)

        Log.actionDetection.info("=== ACTION DETECTION: SENTENCES ===")
        Log.actionDetection.info("Total sentences found: \(sentences.count)")
        for (index, sentence) in sentences.enumerated() {
            Log.actionDetection.info("Sentence \(index): '\(sentence)'")
        }

        guard !sentences.isEmpty else {
            Log.actionDetection.warning("No sentences found, returning 0")
            return 0
        }

        // Step 2: Detect action items
        progress = 0.5
        currentStep = "Detecting action items..."
        var detectedActions: [DetectedAction] = []

        for sentence in sentences {
            if let action = detectAction(in: sentence) {
                Log.actionDetection.info("ACTION FOUND: '\(action.title)' (confidence: \(action.confidence, format: .fixed(precision: 2)))")
                detectedActions.append(action)
            }
        }

        Log.actionDetection.info("Total actions detected: \(detectedActions.count)")

        // Step 3: Extract dates for each action
        progress = 0.7
        currentStep = "Extracting dates..."
        for i in 0..<detectedActions.count {
            detectedActions[i].dueDate = extractDate(from: detectedActions[i].sourceSentence)
        }

        // Step 4: Save to Core Data
        progress = 0.9
        currentStep = "Saving action items..."
        try await saveActionItems(detectedActions, meeting: meeting, context: context)

        progress = 1.0
        currentStep = "Complete"

        return detectedActions.count
    }

    // MARK: - Private Methods

    /// Segment text into sentences using NLTokenizer
    private func segmentSentences(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    /// Common stop words that aren't valid standalone action titles
    private let stopWords: Set<String> = [
        "that", "this", "it", "the", "a", "an", "so", "but", "and", "or",
        "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did",
        "not", "no", "yes", "yeah", "ok", "okay",
        "see", "say", "said", "like", "just", "also", "too",
        "here", "there", "where", "when", "what", "who", "how", "why",
        "very", "really", "actually", "basically", "probably", "maybe",
    ]

    /// Detect if a sentence contains an action item
    private func detectAction(in sentence: String) -> DetectedAction? {
        let lowercased = sentence.lowercased()

        // Length filters: too-short sentences are fragments, too-long ones are likely
        // paragraphs/poems/narrative that happen to contain an action-like word
        let wordCount = lowercased.split(separator: " ").count
        if wordCount < 3 {
            Log.actionDetection.debug("FILTERED (too short, \(wordCount) words): '\(sentence)'")
            return nil
        }
        if sentence.count > 200 {
            Log.actionDetection.debug("FILTERED (too long, \(sentence.count) chars): '\(sentence.prefix(60))...'")
            return nil
        }

        // Negation filter: skip "don't/do not" + verb, but allow "don't forget"
        if isNegated(lowercased) {
            Log.actionDetection.debug("FILTERED (negation): '\(sentence)'")
            return nil
        }

        // Question filter: skip questions unless they contain request patterns
        if isFilteredQuestion(lowercased) {
            Log.actionDetection.debug("FILTERED (question): '\(sentence)'")
            return nil
        }

        // Check against action patterns
        for (pattern, confidence, requiresTaskContext) in actionPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(lowercased.startIndex..., in: lowercased)

                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {

                    // For generic patterns, verify the sentence has task context
                    if requiresTaskContext && !hasTaskIndicators(lowercased) {
                        Log.actionDetection.debug("SKIPPED generic pattern '\(pattern)' (no task context): '\(sentence)'")
                        continue // Try remaining patterns — a specific one might match
                    }

                    // Extract a clean title from the sentence
                    let title = extractActionTitle(from: sentence)

                    // Skip if the extracted title is a single stop word (e.g., "See", "That")
                    let titleWords = title.split(separator: " ")
                    if titleWords.count < 2 && stopWords.contains(title.lowercased()) {
                        Log.actionDetection.debug("FILTERED (stop word title '\(title)'): '\(sentence)'")
                        return nil
                    }
                    // Skip completely empty titles
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Log.actionDetection.debug("FILTERED (empty title): '\(sentence)'")
                        return nil
                    }

                    Log.actionDetection.info("MATCHED pattern '\(pattern)' → title '\(title)' (confidence: \(confidence, format: .fixed(precision: 2)))")
                    return DetectedAction(
                        title: title,
                        sourceSentence: sentence,
                        confidence: confidence,
                        dueDate: nil
                    )
                }
            } catch {
                continue
            }
        }

        return nil
    }

    /// Check if a sentence contains task-related words (verbs, nouns, or time references).
    /// Used to validate generic commitment patterns like "I'll", "we should", etc.
    private func hasTaskIndicators(_ lowercased: String) -> Bool {
        let words = lowercased.split(separator: " ").map(String.init)

        // Check for task verbs (check both single words and two-word phrases)
        for verb in taskVerbs {
            if verb.contains(" ") {
                // Multi-word verb like "pick up" — check in full sentence
                if lowercased.contains(verb) { return true }
            } else {
                // Single-word verb — check word boundaries to avoid partial matches
                if words.contains(verb) { return true }
            }
        }

        // Check for task nouns
        for noun in taskNouns {
            if words.contains(noun) { return true }
        }

        // Check for time indicators (some are multi-word)
        for indicator in timeIndicators {
            if lowercased.contains(indicator) { return true }
        }

        // Check for time patterns: digits followed by am/pm, or HH:MM
        if lowercased.range(of: #"\d{1,2}\s*(am|pm|a\.m|p\.m)"#, options: .regularExpression) != nil {
            return true
        }
        if lowercased.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Check if a sentence is negated (e.g., "don't send that email")
    /// Exception: "don't forget" is still an action
    private func isNegated(_ lowercased: String) -> Bool {
        let negationPrefixes = ["don't ", "dont ", "do not "]
        for prefix in negationPrefixes {
            if lowercased.hasPrefix(prefix) {
                // Exception: "don't forget" remains an action
                let afterPrefix = String(lowercased.dropFirst(prefix.count))
                if afterPrefix.hasPrefix("forget") {
                    return false
                }
                return true
            }
        }
        return false
    }

    /// Check if a sentence is a question that should be filtered out
    /// Questions ending in "?" are excluded UNLESS they contain request patterns
    private func isFilteredQuestion(_ lowercased: String) -> Bool {
        guard lowercased.hasSuffix("?") else { return false }

        let requestPatterns = ["can you", "could you", "will you", "would you", "please"]
        for pattern in requestPatterns {
            if lowercased.contains(pattern) {
                return false // Keep request-style questions
            }
        }
        return true // Filter out non-request questions
    }

    /// Extract a clean action title from the sentence
    private func extractActionTitle(from sentence: String) -> String {
        var title = sentence

        // Remove common prefixes
        let prefixesToRemove = [
            "i'll ", "i will ", "i need to ", "i have to ", "i'm going to ", "i am going to ",
            "i should ", "i must ",
            "i plan to ", "i intend to ", "my plan is to ", "the plan is to ", "the goal is to ",
            "we'll ", "we will ", "we need to ", "we have to ", "we're going to ", "we are going to ",
            "we should ", "let's ",
            "can you ", "could you ", "please ",
            "you need to ", "you should ",
            "don't forget to ", "don't forget ", "dont forget to ", "dont forget ",
            "do not forget to ", "do not forget ",
            "remember to ", "remember ",
            "make sure to ", "make sure ", "be sure to ", "be sure ",
            "action item ", "todo ", "to-do ",
            "take care of ", "deal with ", "reach out to ", "get back to ",
            "circle back on ", "circle back ", "follow up on ",
            "deadline is ", "due by ", "due at ", "due date ",
            "i have a ", "i have an ", "i've got a ", "i've got an ",
            "i have got a ", "i have got an ",
            "there's a ", "there's an ", "there is a ", "there is an ",
        ]

        let lowercased = title.lowercased()
        for prefix in prefixesToRemove {
            if lowercased.hasPrefix(prefix) {
                let index = title.index(title.startIndex, offsetBy: prefix.count)
                title = String(title[index...])
                break
            }
        }

        // Capitalize first letter
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }

        // Truncate if too long (keep first ~60 chars at word boundary)
        if title.count > 60 {
            let truncated = String(title.prefix(60))
            if let lastSpace = truncated.lastIndex(of: " ") {
                title = String(truncated[..<lastSpace]) + "..."
            }
        }

        // Remove trailing punctuation for cleaner title
        while let last = title.last, ".!?".contains(last) {
            title.removeLast()
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract date from sentence using NSDataDetector and keyword matching
    private func extractDate(from sentence: String) -> Date? {
        // Pre-process: convert spelled-out numbers to digits for better detection
        var processedSentence = sentence.lowercased()
        for (word, digit) in spelledNumbers {
            // Replace "at nine" with "at 9", "at noon" with "at 12", etc.
            processedSentence = processedSentence.replacingOccurrences(of: "at \(word)", with: "at \(digit)")
            processedSentence = processedSentence.replacingOccurrences(of: "\(word) am", with: "\(digit) am")
            processedSentence = processedSentence.replacingOccurrences(of: "\(word) pm", with: "\(digit) pm")
            processedSentence = processedSentence.replacingOccurrences(of: "\(word) o'clock", with: "\(digit) o'clock")
            processedSentence = processedSentence.replacingOccurrences(of: "\(word) oclock", with: "\(digit) oclock")
        }

        var resultDate: Date?

        // First try NSDataDetector for explicit dates
        if let detectorDate = extractDateWithDetector(from: processedSentence) {
            resultDate = detectorDate
        }

        // Also try the original sentence in case processing broke something
        if resultDate == nil, let detectorDate = extractDateWithDetector(from: sentence) {
            resultDate = detectorDate
        }

        // Fall back to keyword matching for relative dates
        if resultDate == nil {
            resultDate = extractRelativeDate(from: sentence)
        }

        // Enrich with time-of-day if found
        if let date = resultDate {
            return enrichWithTimeOfDay(date: date, from: processedSentence)
        }

        // Even without a date, check for time-only mentions (e.g., "by 3pm" implies today)
        if let timeDate = extractTimeOfDay(from: processedSentence) {
            return timeDate
        }

        return nil
    }

    /// Extract time-of-day from sentence and apply to a date
    private func enrichWithTimeOfDay(date: Date, from lowercased: String) -> Date {
        let calendar = Calendar.current

        if let timeComponents = extractTimeComponents(from: lowercased) {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            return calendar.date(from: components) ?? date
        }

        return date
    }

    /// Extract time-of-day as a Date (today) from sentence
    private func extractTimeOfDay(from lowercased: String) -> Date? {
        guard let timeComponents = extractTimeComponents(from: lowercased) else { return nil }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }

    /// Parse time components from text like "by 3pm", "before noon", "eod", "at 2:30 pm"
    private func extractTimeComponents(from lowercased: String) -> (hour: Int, minute: Int)? {
        // "eod" / "end of day" → 17:00
        if lowercased.contains("eod") || lowercased.contains("end of day") {
            return (hour: 17, minute: 0)
        }

        // "before noon" → 12:00
        if lowercased.contains("before noon") {
            return (hour: 12, minute: 0)
        }

        // Match patterns like "by 3pm", "at 3:30 pm", "by 3 pm", "at 15:00"
        let timePattern = #"(?:by|at|before)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let hourRange = Range(match.range(at: 1), in: lowercased),
              var hour = Int(lowercased[hourRange]) else {
            return nil
        }

        let minute: Int
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: lowercased),
           let parsedMinute = Int(lowercased[minuteRange]) {
            minute = parsedMinute
        } else {
            minute = 0
        }

        // Handle AM/PM
        if match.range(at: 3).location != NSNotFound,
           let ampmRange = Range(match.range(at: 3), in: lowercased) {
            let ampm = String(lowercased[ampmRange]).lowercased()
            if ampm.hasPrefix("p") && hour < 12 {
                hour += 12
            } else if ampm.hasPrefix("a") && hour == 12 {
                hour = 0
            }
        }

        guard hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 else { return nil }
        return (hour: hour, minute: minute)
    }

    /// Use NSDataDetector to find dates
    private func extractDateWithDetector(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        // Return the first date found
        return matches.first?.date
    }

    /// Extract relative dates from keywords
    private func extractRelativeDate(from sentence: String) -> Date? {
        let lowercased = sentence.lowercased()
        let calendar = Calendar.current

        // Check for "ASAP" / "as soon as possible" → tomorrow
        if lowercased.contains("asap") || lowercased.contains("as soon as possible") {
            return calendar.date(byAdding: .day, value: 1, to: Date())
        }

        // Check for "end of month" / "by end of month"
        if lowercased.contains("end of month") || lowercased.contains("end of the month") {
            // Get last day of current month
            guard let monthRange = calendar.range(of: .day, in: .month, for: Date()),
                  let lastDay = calendar.date(bySetting: .day, value: monthRange.count, of: Date()) else {
                return nil
            }
            return lastDay
        }

        // Check for "within a week/month"
        if lowercased.contains("within a week") {
            return calendar.date(byAdding: .day, value: 7, to: Date())
        }
        if lowercased.contains("within a month") {
            return calendar.date(byAdding: .month, value: 1, to: Date())
        }

        // Check for "in X days/weeks/months" pattern
        if let relativeDate = extractInXUnitsDate(from: lowercased) {
            return relativeDate
        }

        // Check for relative date keywords
        for (keyword, daysOffset) in relativeDateKeywords {
            if lowercased.contains(keyword) {
                switch daysOffset {
                case -1: // Next weekday
                    return nextWeekday(from: keyword)
                case -2: // End of week (Friday)
                    return nextWeekday(named: "friday")
                case -3: // By Friday
                    return nextWeekday(named: "friday")
                case -4: // By Monday
                    return nextWeekday(named: "monday")
                default:
                    return calendar.date(byAdding: .day, value: daysOffset, to: Date())
                }
            }
        }

        return nil
    }

    /// Parse "in X days/weeks/months" patterns
    private func extractInXUnitsDate(from lowercased: String) -> Date? {
        let calendar = Calendar.current

        // Match "in <number> day(s)/week(s)/month(s)"
        let pattern = #"in\s+(\d+)\s+(day|days|week|weeks|month|months)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let numberRange = Range(match.range(at: 1), in: lowercased),
              let unitRange = Range(match.range(at: 2), in: lowercased),
              let number = Int(lowercased[numberRange]) else {
            return nil
        }

        let unit = String(lowercased[unitRange])
        switch unit {
        case "day", "days":
            return calendar.date(byAdding: .day, value: number, to: Date())
        case "week", "weeks":
            return calendar.date(byAdding: .day, value: number * 7, to: Date())
        case "month", "months":
            return calendar.date(byAdding: .month, value: number, to: Date())
        default:
            return nil
        }
    }

    /// Get next occurrence of a weekday
    private func nextWeekday(from keyword: String) -> Date? {
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let lowercased = keyword.lowercased()

        for (index, day) in weekdays.enumerated() {
            if lowercased.contains(day) {
                return nextWeekday(weekdayIndex: index + 1) // Calendar weekdays are 1-indexed
            }
        }
        return nil
    }

    private func nextWeekday(named name: String) -> Date? {
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        guard let index = weekdays.firstIndex(of: name.lowercased()) else { return nil }
        return nextWeekday(weekdayIndex: index + 1)
    }

    private func nextWeekday(weekdayIndex: Int) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = weekdayIndex - todayWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: today)
    }

    /// Save detected actions to Core Data
    private func saveActionItems(
        _ actions: [DetectedAction],
        meeting: Meeting,
        context: NSManagedObjectContext
    ) async throws {
        // Capture objectID before entering perform block to avoid Sendable warning
        let meetingObjectID = meeting.objectID

        try await context.perform {
            // Fetch the meeting inside the perform block
            guard let meetingInContext = try? context.existingObject(with: meetingObjectID) as? Meeting else {
                return
            }

            for action in actions {
                let item = ActionItem(context: context)
                item.id = UUID()
                item.title = action.title
                item.sourceSentence = action.sourceSentence
                item.confidence = action.confidence
                item.dueDate = action.dueDate
                item.isIncluded = action.confidence >= 0.75 // Auto-include detected action items
                item.meeting = meetingInContext
            }

            try context.save()
        }
    }
}

// MARK: - Supporting Types

private struct DetectedAction {
    let title: String
    let sourceSentence: String
    let confidence: Double
    var dueDate: Date?
}
