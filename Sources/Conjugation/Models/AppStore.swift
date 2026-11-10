import Foundation
#if os(Android)
import Observation
import SkipFuse
#else
import Combine
#endif

struct PracticeSettings: Codable, Equatable {
    var selectedTenses: Set<Tense> = [.present]
    var selectedPeople: Set<Int> = Set(0..<6)
    var randomOrder = false
    var randomPerson = false
    var sessionLength = 5 // 0 = every selected verb / tense combination
    var dailyGoal = 5
    var ignoreAccents = false
    var playAfterCheck = false
}

struct DayProgress: Codable {
    var attempts = 0
    var correct = 0
}

struct PracticeQuestion: Identifiable, Hashable {
    let verb: Verb
    let tense: Tense
    let people: [Int]
    var id: String { verb.id + ":" + tense.rawValue }
}

struct PracticeSession: Identifiable {
    let id = UUID()
    let title: String
    let questions: [PracticeQuestion]

    static func make(title: String, verbs: [Verb], settings: PracticeSettings) -> PracticeSession? {
        var questions: [PracticeQuestion] = []
        for verb in verbs {
            for tense in Tense.allCases where settings.selectedTenses.contains(tense) {
                var people = (0..<6).filter {
                    settings.selectedPeople.contains($0) && !verb.answers(tense, person: $0).isEmpty
                }
                if settings.randomPerson, let one = people.randomElement() { people = [one] }
                if !people.isEmpty { questions.append(.init(verb: verb, tense: tense, people: people)) }
            }
        }
        if settings.randomOrder { questions.shuffle() }
        if settings.sessionLength > 0 { questions = Array(questions.prefix(settings.sessionLength)) }
        guard !questions.isEmpty else { return nil }
        return PracticeSession(title: title, questions: questions)
    }
}

#if os(Android)
@Observable
#endif
@MainActor
final class AppStore {
    let lexicon = Lexicon()
    private let defaults: UserDefaults
    #if !os(Android)
    @Published
    #endif
    var settings: PracticeSettings { didSet { persist() } }
    #if !os(Android)
    @Published
    #endif
    var favorites: Set<String> { didSet { persist() } }
    #if !os(Android)
    @Published
    #endif
    var excluded: Set<String> { didSet { persist() } }
    #if !os(Android)
    @Published
    #endif
    var mistakes: Set<String> { didSet { persist() } }
    #if !os(Android)
    @Published
    #endif
    var progress: [String: DayProgress] { didSet { persist() } }
    private var roundOffsets: [String: Int]

    private struct Saved: Codable {
        var settings: PracticeSettings
        var favorites: Set<String>
        var excluded: Set<String>
        var mistakes: Set<String>
        var progress: [String: DayProgress]
        var roundOffsets: [String: Int]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-state-for-testing") {
            defaults.removeObject(forKey: "conjugation.state.v1")
        }
        #endif
        var saved: Saved?
        if let data = defaults.data(forKey: "conjugation.state.v1") {
            do { saved = try JSONDecoder().decode(Saved.self, from: data) }
            catch { AppDiagnostics.error("读取学习记录失败，使用默认设置", category: "学习记录", error: error) }
        }
        var restored = saved?.settings ?? PracticeSettings()
        if restored.selectedPeople.isEmpty {
            AppDiagnostics.warning("已保存的人称选择为空，恢复为全部人称", category: "练习设置")
            restored.selectedPeople = Set(0..<6)
        }
        if restored.selectedTenses.isEmpty {
            AppDiagnostics.warning("已保存的时态选择为空，恢复为现在时", category: "练习设置")
            restored.selectedTenses = [.present]
        }
        if restored.dailyGoal < 1 { AppDiagnostics.warning("已保存的每日目标无效，恢复为 1", category: "练习设置") }
        restored.dailyGoal = max(1, restored.dailyGoal)
        settings = restored
        favorites = saved?.favorites ?? []
        excluded = saved?.excluded ?? []
        mistakes = saved?.mistakes ?? []
        progress = saved?.progress ?? [:]
        roundOffsets = saved?.roundOffsets ?? [:]
    }

    private func persist() {
        let saved = Saved(settings: settings, favorites: favorites, excluded: excluded, mistakes: mistakes, progress: progress, roundOffsets: roundOffsets)
        do { defaults.set(try JSONEncoder().encode(saved), forKey: "conjugation.state.v1") }
        catch { AppDiagnostics.error("保存学习记录失败", category: "学习记录", error: error) }
    }

    static func dayKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
    var today: DayProgress { progress[Self.dayKey(Date())] ?? DayProgress() }
    var goalProgress: Double { min(Double(today.correct) / Double(max(settings.dailyGoal,1)), 1) }
    var totalCorrect: Int { progress.values.reduce(0) { $0 + $1.correct } }
    var streak: Int {
        let calendar = Calendar.current
        var date = Date()
        if (progress[Self.dayKey(date)]?.correct ?? 0) == 0 {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        var count = 0
        while (progress[Self.dayKey(date)]?.correct ?? 0) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }
    func recentDays() -> [(date: Date, value: DayProgress)] {
        (0..<7).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (date, progress[Self.dayKey(date)] ?? DayProgress())
        }
    }
    func toggleFavorite(_ verb: Verb) {
        if favorites.contains(verb.id) { favorites.remove(verb.id) } else { favorites.insert(verb.id) }
    }
    func setSelected(_ verb: Verb, selected: Bool) {
        if selected { excluded.remove(verb.id) } else { excluded.insert(verb.id) }
    }
    func startSession(title: String, verbs: [Verb], override: PracticeSettings? = nil) -> PracticeSession? {
        let chosen = override ?? settings
        var fullSettings = chosen
        fullSettings.sessionLength = 0
        guard let full = PracticeSession.make(title: title, verbs: verbs, settings: fullSettings) else {
            AppDiagnostics.warning("无法创建练习：当前动词、时态与人称组合没有有效题目", category: "练习出题")
            return nil
        }
        guard chosen.sessionLength > 0 else { return full }
        let count = min(chosen.sessionLength, full.questions.count)
        if chosen.randomOrder { return PracticeSession(title: title, questions: Array(full.questions.prefix(count))) }
        // Continue ordered short rounds through the list instead of repeating the
        // first five verbs on every launch.
        let key = title + "|" + Tense.allCases.filter { chosen.selectedTenses.contains($0) }.map(\.rawValue).joined(separator: ",")
        let offset = (roundOffsets[key] ?? 0) % full.questions.count
        let questions = (0..<count).map { full.questions[(offset + $0) % full.questions.count] }
        roundOffsets[key] = (offset + count) % full.questions.count
        persist()
        return PracticeSession(title: title, questions: questions)
    }
    func record(question: PracticeQuestion, results: [Int: Bool], helped: Bool) {
        let key = Self.dayKey(Date())
        var day = progress[key] ?? DayProgress()
        day.attempts += results.count
        if !helped { day.correct += results.values.filter { $0 }.count }
        progress[key] = day
        if results.values.allSatisfy({ $0 }) && !helped {
            mistakes.remove(question.id)
        } else {
            mistakes.insert(question.id)
        }
    }
    func mistakeSession() -> PracticeSession? {
        let questions = lexicon.verbs.flatMap { verb in
            Tense.allCases.compactMap { tense -> PracticeQuestion? in
                let people = (0..<6).filter { !verb.answers(tense, person: $0).isEmpty }
                let question = PracticeQuestion(verb: verb, tense: tense, people: people)
                return mistakes.contains(question.id) && !people.isEmpty ? question : nil
            }
        }
        guard !questions.isEmpty else { return nil }
        return PracticeSession(title: "错题复习", questions: questions)
    }
    func resetProgress() { progress = [:]; mistakes = [] }
}

#if !os(Android)
extension AppStore: ObservableObject {}
#endif
