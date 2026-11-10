import XCTest
@testable import Conjugation

final class ConjugationTests: XCTestCase {
    private var lexicon: Lexicon { Lexicon() }
    private func verb(_ id: String) -> Verb { lexicon.verbs.first { $0.id == id }! }

    func testLexiconCoverageAndBasicGroups() {
        XCTAssertNil(lexicon.error)
        XCTAssertEqual(lexicon.verbs.count, 776)
        XCTAssertEqual(Set(lexicon.verbs.map(\.id)).count, 776)
        XCTAssertEqual(VerbLevel.allCases.map { level in lexicon.verbs.filter { $0.level == level }.count }, [21,66,68,162,459])
        let basic = lexicon.verbs.filter { $0.level == .basic }
        XCTAssertEqual(VerbGroup.allCases.map { group in basic.filter { $0.group == group }.count }, [5,3,4,9])
        for verb in lexicon.verbs {
            for tense in Tense.allCases {
                XCTAssertEqual(verb.forms[tense.rawValue]?.count, 6, "\(verb.id), \(tense)")
            }
        }
    }

    func testKnownConjugationsAndOrthography() {
        XCTAssertEqual((0..<6).map { verb("perdre").answers(.present, person: $0).first! }, ["perds","perds","perd","perdons","perdez","perdent"])
        XCTAssertEqual(verb("manger").answers(.present, person: 3), ["mangeons"])
        XCTAssertEqual(verb("nager").answers(.imperfect, person: 0), ["nageais"])
        XCTAssertEqual(verb("finir").answers(.present, person: 3), ["finissons"])
        XCTAssertEqual(verb("envoyer").answers(.future, person: 0), ["enverrai"])
        XCTAssertEqual(verb("être").answers(.subjunctivePresent, person: 3), ["soyons"])
        XCTAssertEqual(verb("avoir").answers(.conditionalPresent, person: 4), ["auriez"])
    }

    func testCompoundTensesAndGenderAlternatives() {
        XCTAssertEqual(verb("perdre").answers(.perfect, person: 3), ["avons perdu"])
        XCTAssertEqual(verb("être").answers(.perfect, person: 0), ["ai été"])
        XCTAssertTrue(verb("aller").answers(.perfect, person: 2).contains("est allée"))
        XCTAssertTrue(verb("aller").answers(.perfect, person: 5).contains("sont allées"))
        XCTAssertTrue(verb("descendre").answers(.perfect, person: 0).contains("ai descendu"))
        XCTAssertTrue(verb("descendre").answers(.perfect, person: 0).contains("suis descendu"))
        XCTAssertEqual(verb("faire").answers(.pluperfect, person: 0), ["avais fait"])
        XCTAssertEqual(verb("faire").answers(.futurePerfect, person: 0), ["aurai fait"])
    }

    func testAnswerNormalizationAndStrictAccents() {
        XCTAssertTrue(AnswerChecker.matches("  JE  PERDS ", accepted: ["perds"], person: 0, ignoreAccents: false))
        XCTAssertTrue(AnswerChecker.matches("j’ai  mangé", accepted: ["ai mangé"], person: 0, ignoreAccents: false))
        XCTAssertTrue(AnswerChecker.matches("qu’il soit", accepted: ["soit"], person: 2, ignoreAccents: false))
        XCTAssertTrue(AnswerChecker.matches("e\u{301}coute", accepted: ["écoute"], person: 0, ignoreAccents: false))
        XCTAssertFalse(AnswerChecker.matches("ecoute", accepted: ["écoute"], person: 0, ignoreAccents: false))
        XCTAssertTrue(AnswerChecker.matches("ecoute", accepted: ["écoute"], person: 0, ignoreAccents: true))
        XCTAssertFalse(AnswerChecker.matches("tu perds", accepted: ["perds"], person: 0, ignoreAccents: true))
        XCTAssertFalse(AnswerChecker.matches("", accepted: [""], person: 0, ignoreAccents: true))
    }

    func testSearchInFrenchAndChinese() {
        XCTAssertTrue(lexicon.search("ETRE").contains { $0.id == "être" })
        XCTAssertTrue(lexicon.search("游泳").contains { $0.id == "nager" })
        XCTAssertTrue(lexicon.search(" Réussir ").contains { $0.id == "réussir" })
        XCTAssertEqual(lexicon.search("不存在的动词").count, 0)
    }

    func testSessionFiltersAndImperativePeople() {
        var settings = PracticeSettings()
        settings.selectedTenses = [.imperativePresent]
        let session = PracticeSession.make(title: "Test", verbs: [verb("aimer")], settings: settings)!
        XCTAssertEqual(session.questions[0].people, [1,3,4])
        settings.selectedPeople = [0,2,5]
        XCTAssertNil(PracticeSession.make(title: "Test", verbs: [verb("aimer")], settings: settings))
        settings.selectedTenses = [.present]
        settings.randomPerson = true
        let random = PracticeSession.make(title: "Test", verbs: [verb("être")], settings: settings)!
        XCTAssertEqual(random.questions[0].people.count, 1)
        XCTAssertTrue([0,2,5].contains(random.questions[0].people[0]))
        settings.sessionLength = 5
        XCTAssertEqual(PracticeSession.make(title: "Test", verbs: lexicon.verbs, settings: settings)?.questions.count, 5)
        settings.sessionLength = 0
        XCTAssertEqual(PracticeSession.make(title: "Test", verbs: lexicon.verbs, settings: settings)?.questions.count, 776)
        XCTAssertNil(PracticeSession.make(title: "Empty", verbs: [], settings: settings))
    }

    func testDefectiveVerbPeopleAreSkipped() {
        let rain = verb("pleuvoir")
        XCTAssertTrue(rain.answers(.present, person: 0).isEmpty)
        XCTAssertEqual(rain.answers(.present, person: 2), ["pleut"])
        XCTAssertTrue(rain.answers(.perfect, person: 0).isEmpty)
        XCTAssertEqual(rain.answers(.perfect, person: 2), ["a plu"])
        XCTAssertTrue((0..<6).allSatisfy { rain.answers(.imperativePresent, person: $0).isEmpty })
    }

    @MainActor
    func testOrderedShortRoundsContinueThroughTheList() {
        let suite = "ConjugationRounds.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        let basic = lexicon.verbs.filter { $0.level == .basic }
        XCTAssertEqual(store.startSession(title: "基本", verbs: basic)?.questions.first?.verb.id, "aimer")
        XCTAssertEqual(store.startSession(title: "基本", verbs: basic)?.questions.first?.verb.id, "choisir")
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.startSession(title: "基本", verbs: basic)?.questions.first?.verb.id, "perdre")
    }

    @MainActor
    func testStatePersistenceAndScoring() {
        let suite = "ConjugationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        let perdre = verb("perdre")
        store.toggleFavorite(perdre)
        store.setSelected(perdre, selected: false)
        store.settings.dailyGoal = 10
        let question = PracticeQuestion(verb: perdre, tense: .present, people: [0,1,2,3,4,5])
        store.record(question: question, results: [0:true,1:true,2:true,3:false,4:false,5:false], helped: false)
        XCTAssertEqual(store.today.correct, 3)
        XCTAssertEqual(store.today.attempts, 6)
        XCTAssertTrue(store.mistakes.contains(question.id))
        XCTAssertEqual(store.mistakeSession()?.questions.count, 1)
        let restored = AppStore(defaults: defaults)
        XCTAssertTrue(restored.favorites.contains("perdre"))
        XCTAssertTrue(restored.excluded.contains("perdre"))
        XCTAssertEqual(restored.settings.dailyGoal, 10)
        XCTAssertEqual(restored.today.correct, 3)
        restored.record(question: question, results: [0:true], helped: true)
        XCTAssertEqual(restored.today.correct, 3)
        XCTAssertEqual(restored.today.attempts, 7)
        restored.record(question: question, results: [0:true], helped: false)
        XCTAssertFalse(restored.mistakes.contains(question.id))
        restored.resetProgress()
        XCTAssertEqual(restored.today.correct, 0)
        XCTAssertTrue(restored.favorites.contains("perdre"))
    }
}
