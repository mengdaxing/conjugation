#if os(Android) && DEBUG
import Foundation
import SkipFuse

/// Exercised through the debug launcher's verifyCore intent on an isolated emulator.
@MainActor
enum AndroidVerification {
    static func run(_ phase: String) -> String {
        var failures: [String] = []
        var count = 0
        func check(_ condition: Bool, _ message: String) {
            count += 1
            if !condition { failures.append(message) }
        }
        let lexicon = Lexicon()
        check(lexicon.error == nil, "resource bundle")
        check(lexicon.verbs.count == 776, "776 verbs")
        check(VerbLevel.allCases.map { level in lexicon.verbs.filter { $0.level == level }.count } == [21, 66, 68, 162, 459], "level counts")
        check(lexicon.verbs.allSatisfy { verb in Tense.allCases.allSatisfy { verb.forms[$0.rawValue]?.count == 6 } }, "16 tenses, six slots")
        check(lexicon.search("ETRE").contains { $0.id == "être" }, "accent-insensitive search")
        check(lexicon.search("游泳").contains { $0.id == "nager" }, "Chinese search")
        check(AnswerChecker.matches("  JE  PERDS ", accepted: ["perds"], person: 0, ignoreAccents: false), "case, subject, whitespace")
        check(AnswerChecker.matches("j’ai mangé", accepted: ["ai mangé"], person: 0, ignoreAccents: false), "curly apostrophe")
        check(AnswerChecker.matches("e\u{301}coute", accepted: ["écoute"], person: 0, ignoreAccents: false), "Unicode normalization")
        check(!AnswerChecker.matches("ecoute", accepted: ["écoute"], person: 0, ignoreAccents: false), "strict accents")
        check(AnswerChecker.matches("ecoute", accepted: ["écoute"], person: 0, ignoreAccents: true), "optional accents")
        check(!AnswerChecker.matches("tu perds", accepted: ["perds"], person: 0, ignoreAccents: true), "wrong subject")
        if let aller = lexicon.verbs.first(where: { $0.id == "aller" }) {
            check(aller.answers(.perfect, person: 2).contains("est allée"), "compound gender variant")
            var settings = PracticeSettings()
            settings.selectedTenses = [.imperativePresent]
            check(PracticeSession.make(title: "Test", verbs: [aller], settings: settings)?.questions.first?.people == [1, 3, 4], "imperative people")
            settings.selectedPeople = [0, 2, 5]
            check(PracticeSession.make(title: "Test", verbs: [aller], settings: settings) == nil, "empty applicable people")
        } else { check(false, "aller missing") }
        let suite = "FrenchVerbs.AndroidVerification"
        if let defaults = UserDefaults(suiteName: suite), let perdre = lexicon.verbs.first(where: { $0.id == "perdre" }) {
            if phase == "write" {
                defaults.removeObject(forKey: "conjugation.state.v1")
                let store = AppStore(defaults: defaults)
                store.toggleFavorite(perdre)
                store.setSelected(perdre, selected: false)
                store.settings.dailyGoal = 13
                let question = PracticeQuestion(verb: perdre, tense: .present, people: Array(0..<6))
                store.record(question: question, results: [0: true, 1: true, 2: true, 3: false, 4: false, 5: false], helped: false)
                let basic = lexicon.verbs.filter { $0.level == .basic }
                check(store.startSession(title: "验证", verbs: basic)?.questions.first?.verb.id == "aimer", "ordered first round")
                _ = defaults.synchronize()
            } else if phase == "read" {
                let store = AppStore(defaults: defaults)
                check(store.favorites.contains("perdre"), "favorites survive process restart")
                check(store.excluded.contains("perdre"), "selection survives process restart")
                check(store.settings.dailyGoal == 13, "settings survive process restart")
                check(store.today.correct == 3 && store.today.attempts == 6, "score survives process restart")
                check(store.mistakeSession()?.questions.count == 1, "mistakes survive process restart")
                let basic = lexicon.verbs.filter { $0.level == .basic }
                check(store.startSession(title: "验证", verbs: basic)?.questions.first?.verb.id == "choisir", "ordered round survives process restart")
                let question = PracticeQuestion(verb: perdre, tense: .present, people: Array(0..<6))
                store.record(question: question, results: [0: true], helped: true)
                check(store.today.correct == 3, "helped answer does not increase score")
                store.record(question: question, results: [0: true], helped: false)
                check(!store.mistakes.contains(question.id), "correct answer removes mistake")
                store.resetProgress()
                check(store.today.correct == 0 && store.favorites.contains("perdre"), "reset preserves favorites")
                defaults.removeObject(forKey: "conjugation.state.v1")
                _ = defaults.synchronize()
            }
        } else { check(false, "verification defaults") }
        return failures.isEmpty ? "PASS \(phase): \(count) checks" : "FAIL \(phase): \(failures.joined(separator: "; "))"
    }
}
#endif
