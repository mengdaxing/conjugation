import Foundation

enum VerbLevel: String, CaseIterable, Codable, Identifiable {
    case basic, beginner, intermediate1, intermediate2, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .basic: return "基本"
        case .beginner: return "初级"
        case .intermediate1: return "中级 1"
        case .intermediate2: return "中级 2"
        case .advanced: return "高级"
        }
    }
}

enum VerbGroup: String, Codable, CaseIterable, Identifiable {
    case er, ir, re, irregular
    var id: String { rawValue }
    var title: String { self == .irregular ? "不规则动词" : "\(rawValue) 动词" }
}

enum Mood: String, CaseIterable, Identifiable {
    case indicative, subjunctive, conditional, imperative
    var id: String { rawValue }
    var title: String {
        switch self {
        case .indicative: return "Indicatif"
        case .subjunctive: return "Subjonctif"
        case .conditional: return "Conditionnel"
        case .imperative: return "Impératif"
        }
    }
    var chinese: String {
        switch self {
        case .indicative: return "直陈式"
        case .subjunctive: return "虚拟式"
        case .conditional: return "条件式"
        case .imperative: return "命令式"
        }
    }
}

enum Tense: String, CaseIterable, Codable, Identifiable {
    case present, perfect, imperfect, future, pluperfect, futurePerfect, simplePast, pastAnterior
    case subjunctivePresent, subjunctivePast, subjunctiveImperfect, subjunctivePluperfect
    case conditionalPresent, conditionalPast, imperativePresent, imperativePast
    var id: String { rawValue }
    var mood: Mood {
        switch self {
        case .subjunctivePresent, .subjunctivePast, .subjunctiveImperfect, .subjunctivePluperfect: return .subjunctive
        case .conditionalPresent, .conditionalPast: return .conditional
        case .imperativePresent, .imperativePast: return .imperative
        default: return .indicative
        }
    }
    var title: String {
        switch self {
        case .present, .subjunctivePresent, .conditionalPresent, .imperativePresent: return "Présent"
        case .perfect: return "Passé composé"
        case .imperfect, .subjunctiveImperfect: return "Imparfait"
        case .future: return "Futur"
        case .pluperfect, .subjunctivePluperfect: return "Plus-que-parfait"
        case .futurePerfect: return "Futur antérieur"
        case .simplePast: return "Passé simple"
        case .pastAnterior: return "Passé antérieur"
        case .subjunctivePast, .conditionalPast, .imperativePast: return "Passé"
        }
    }
    var chinese: String {
        switch self {
        case .present: return "现在时"
        case .perfect: return "复合过去时"
        case .imperfect: return "未完成过去时"
        case .future: return "简单将来时"
        case .pluperfect: return "愈过去时"
        case .futurePerfect: return "先将来时"
        case .simplePast: return "简单过去时"
        case .pastAnterior: return "先过去时"
        case .subjunctivePresent: return "虚拟式现在时"
        case .subjunctivePast: return "虚拟式过去时"
        case .subjunctiveImperfect: return "虚拟式未完成过去时"
        case .subjunctivePluperfect: return "虚拟式愈过去时"
        case .conditionalPresent: return "条件式现在时"
        case .conditionalPast: return "条件式过去时"
        case .imperativePresent: return "命令式现在时"
        case .imperativePast: return "命令式过去时"
        }
    }
    var explanation: String {
        switch self {
        case .present: return "表达现在的动作、习惯或普遍事实。规则 -er 动词词尾：-e, -es, -e, -ons, -ez, -ent。"
        case .perfect: return "表达已完成的过去动作。使用 avoir 或 être 的现在时，加过去分词。être 作助动词时，过去分词须与主语性数配合。"
        case .imperfect: return "描述过去的状态、习惯或背景。通常取 nous 现在时去掉 -ons，再加 -ais, -ais, -ait, -ions, -iez, -aient。"
        case .future: return "表达将来的动作。通常以不定式为词干，加 -ai, -as, -a, -ons, -ez, -ont；-re 动词去掉末尾的 e。"
        case .pluperfect: return "表达过去某个时间之前已经完成的动作。助动词的未完成过去时 + 过去分词。"
        case .futurePerfect: return "表达将来某个时间之前完成的动作。助动词的简单将来时 + 过去分词。"
        case .simplePast: return "主要用于书面叙述，表示过去已经完成的事件。口语通常使用复合过去时。"
        case .pastAnterior: return "主要用于书面语，表示先于另一过去事件完成的动作。助动词的简单过去时 + 过去分词。"
        case .subjunctivePresent: return "常接在 que 后，表达愿望、必要、怀疑或情感。此处填写动词本身，无需输入 que。"
        case .subjunctivePast: return "表达虚拟式语境中已经完成的动作。助动词的虚拟式现在时 + 过去分词。"
        case .subjunctiveImperfect: return "主要用于文学语言中的过去虚拟式语境。此处无需输入 que。"
        case .subjunctivePluperfect: return "主要用于文学语言，表达虚拟式语境中更早完成的动作。助动词的虚拟式未完成过去时 + 过去分词。"
        case .conditionalPresent: return "表达假设、愿望或礼貌请求。通常使用将来时词干，加未完成过去时词尾。"
        case .conditionalPast: return "表达过去的假设、未实现的愿望。助动词的条件式现在时 + 过去分词。"
        case .imperativePresent: return "用于命令、建议或请求。只有 tu、nous、vous 三种形式，实际使用时省略主语代词。"
        case .imperativePast: return "要求在某个时间之前完成动作。助动词的命令式 + 过去分词。只有 tu、nous、vous 三种形式。"
        }
    }
}

struct Person: Identifiable {
    let id: Int
    let pronoun: String
    let title: String
    let detail: String
    static let all: [Person] = [
        .init(id: 0, pronoun: "je", title: "Je（我）", detail: "第一人称单数"),
        .init(id: 1, pronoun: "tu", title: "Tu（你 / 非正式）", detail: "第二人称单数"),
        .init(id: 2, pronoun: "il / elle", title: "Il / Elle（他 / 她 / 它）", detail: "第三人称单数"),
        .init(id: 3, pronoun: "nous", title: "Nous（我们）", detail: "第一人称复数"),
        .init(id: 4, pronoun: "vous", title: "Vous（您 / 你们）", detail: "第二人称复数 / 敬称"),
        .init(id: 5, pronoun: "ils / elles", title: "Ils / Elles（他们 / 她们）", detail: "第三人称复数")
    ]
}

struct Verb: Codable, Identifiable, Hashable {
    let id: String
    let meaning: String
    let level: VerbLevel
    let group: VerbGroup
    let forms: [String: [[String]]]
    var title: String { id.prefix(1).uppercased() + id.dropFirst() }
    func answers(_ tense: Tense, person: Int) -> [String] {
        guard let slots = forms[tense.rawValue], slots.indices.contains(person) else { return [] }
        return slots[person]
    }
    static func == (lhs: Verb, rhs: Verb) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Lexicon {
    let verbs: [Verb]
    let error: String?
    init(bundle: Bundle = AppResources.bundle) {
        do {
            guard let url = bundle.url(forResource: "verbs", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            verbs = try JSONDecoder().decode([Verb].self, from: Data(contentsOf: url))
            error = nil
        } catch {
            verbs = []
            self.error = "离线词库载入失败：\(error.localizedDescription)"
            AppDiagnostics.error("离线词库载入失败", category: "词库", error: error)
        }
    }
    func search(_ query: String) -> [Verb] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return verbs }
        return verbs.filter {
            $0.id.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
                .contains(q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")))
                || $0.meaning.contains(q)
        }
    }
}

enum AnswerChecker {
    static func normalize(_ input: String, ignoreAccents: Bool = false) -> String {
        var text = input.precomposedStringWithCanonicalMapping.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
        text = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if ignoreAccents { text = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr")) }
        return text
    }
    static func matches(_ input: String, accepted: [String], person: Int, ignoreAccents: Bool) -> Bool {
        var normalized = normalize(input, ignoreAccents: ignoreAccents)
        // Accept a correctly supplied subject as well as the bare verb.
        if normalized.hasPrefix("que ") { normalized = String(normalized.dropFirst(4)) }
        if normalized.hasPrefix("qu'") { normalized = String(normalized.dropFirst(3)) }
        let prefixes = [["je ", "j'"], ["tu "], ["il ", "elle ", "on "], ["nous "], ["vous "], ["ils ", "elles "]]
        if prefixes.indices.contains(person), let prefix = prefixes[person].first(where: { normalized.hasPrefix($0) }) {
            normalized = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return !normalized.isEmpty && accepted.contains { normalize($0, ignoreAccents: ignoreAccents) == normalized }
    }
}

/// Resources live in the app bundle for Xcode and in the module bundle for SwiftPM.
enum AppResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
