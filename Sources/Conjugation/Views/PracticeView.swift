import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PracticeView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @Environment(\.dismiss) var dismiss
    let session: PracticeSession
    #if os(Android)
    @State var speaker = FrenchSpeaker()
    #else
    @StateObject var speaker = FrenchSpeaker()
    #endif
    @State var index = 0
    @State var answers = Array(repeating: "", count: 6)
    @State var results: [Int: Bool] = [:]
    @State var checked = false
    @State var finished = false
    @State var reference = false
    @State var tenseHelp = false
    @State var showMeaning = false
    @State var quit = false
    @State var recorded: Set<String> = []
    @State var helped: Set<String> = []
    @State var firstResults: [String: [Int: Bool]] = [:]
    @FocusState var focusedPerson: Int?
    var question: PracticeQuestion { session.questions[index] }

    var body: some View {
        NavigationStack {
            content.toolbar(.hidden, for: .navigationBar)
        }
    }

    var content: some View {
        GeometryReader { geometry in
            if finished {
                summary
            } else {
                let compact = geometry.size.height < 650
                let headerHeight = compact ? 120.0 : min(295.0, geometry.size.height * 0.34)
                VStack(spacing: 0) {
                    header(height: headerHeight, compact: compact)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: checked ? 42 : 8)
                                ForEach(question.people, id: \.self) { person in
                                    if checked { feedbackRow(person) }
                                    else { inputRow(person, compact: compact).id(person) }
                                }
                                if checked && helped.contains(question.id) {
                                    Text("本题查看过答案，不计入每日目标")
                                        .font(.caption).foregroundStyle(.secondary).padding(.top,12)
                                }
                                Spacer(minLength: compact ? 8 : 24)
                                actionButtons
                                    .padding(.horizontal, 48).padding(.top, compact ? 8 : 16).padding(.bottom, compact ? 10 : 24)
                            }
                            .frame(maxWidth: min(640, geometry.size.width))
                            .frame(minHeight: max(0, geometry.size.height - headerHeight - (compact ? 44 : 0)), alignment: .center)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        #if !os(Android)
                        .onChange(of: focusedPerson) { person in
                            if let person {
                                // Keep the focused row visible without an animation racing
                                // against the next keypress or the keyboard transition.
                                proxy.scrollTo(person, anchor: .bottom)
                            }
                        }
                        #endif
                    }
                    #if os(Android)
                    if focusedPerson != nil {
                        accentKeyboardBar.padding(.horizontal, 12).padding(.vertical, 8).background(Palette.sky)
                    }
                    #endif
                }.background(.white)
            }
        }
        .background(Palette.sky.ignoresSafeArea(edges: .top))
        .appKeyboardToolbar { accentKeyboardBar }
        .sheet(isPresented: $reference) { VerbReferenceView(verb: question.verb, initialTense: question.tense) }
        .sheet(isPresented: $tenseHelp) { TenseHelpView(tense: question.tense) }
        .confirmationDialog("结束这一轮练习？", isPresented: $quit, titleVisibility: .visible) {
            Button("结束练习", role: .destructive) { speaker.stop(); dismiss() }
            Button("继续练习", role: .cancel) {}
        } message: { Text("已提交的成绩会保留。") }
        .onDisappear { speaker.stop() }
        .speechPlaybackAlert(speaker)
        .onAppear { focusFirst() }
    }

    var accentKeyboardBar: some View {
        HStack(spacing: 0) {
            ForEach(["é", "è", "ê", "à", "ç", "î", "ô", "û"], id: \.self) { accent in
                Button(accent) {
                    if let focusedPerson { answers[focusedPerson].append(accent) }
                }.font(.system(size: 19)).frame(width: 30)
            }
            Spacer(minLength: 6)
            Button { focusedPerson = nil } label: { Image.appSymbol( "keyboard.chevron.compact.down") }
                .frame(width: 32).accessibilityLabel("收起键盘")
        }
        .buttonStyle(.plain).frame(maxWidth: .infinity)
    }

    func header(height: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { focusedPerson = nil; quit = true } label: {
                    HStack(spacing: 6) {
                        Image.appSymbol( "ellipsis.circle").font(.system(size: 21, weight: .semibold))
                        Text("\(index + 1)/\(session.questions.count)").font(.system(size: 18))
                    }
                }.accessibilityLabel("练习菜单，\(index + 1) / \(session.questions.count)")
                    .accessibilityIdentifier("practiceMenu")
                Spacer()
                if checked {
                    Button { readAnswers() } label: { Image.appSymbol( "headphones").font(.system(size: 23)) }
                        .accessibilityLabel("朗读答案").padding(.trailing, 16)
                }
                Button {
                    focusedPerson = nil
                    if !checked { helped.insert(question.id) }
                    reference = true
                } label: { Image.appSymbol( "eyeglasses").font(.system(size: 25)) }
                    .accessibilityLabel("查看变位表").accessibilityIdentifier("showAnswers")
            }.foregroundStyle(Palette.blue).padding(.horizontal, 20).padding(.top, compact ? 8 : 18)
            Spacer(minLength: compact ? 6 : 12)
            Button { withAnimation { showMeaning.toggle() } } label: {
                HStack(spacing: 9) {
                    Text(question.verb.title).font(.system(size: compact ? 24 : 27, weight: .bold)).foregroundStyle(Palette.text)
                    Image.appSymbol( showMeaning ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.blue)
                }
            }.accessibilityIdentifier("questionVerb")
            if showMeaning {
                Text(question.verb.meaning).font(.subheadline).foregroundStyle(.secondary).padding(.top, 5)
            }
            Button { focusedPerson = nil; tenseHelp = true } label: {
                HStack(spacing: 9) {
                    Text(question.tense.title).foregroundStyle(Palette.text)
                    Image.appSymbol( "book").foregroundStyle(Palette.blue)
                }.font(.system(size: compact ? 18 : 21)).padding(.top, compact ? 4 : 6)
            }.accessibilityLabel("\(question.tense.chinese)说明")
            if question.tense.mood != .indicative {
                Text(question.tense.mood.title).font(.caption).foregroundStyle(Palette.blue).padding(.top, 4)
            }
            Spacer(minLength: compact ? 10 : 22)
        }.frame(height: height).background(Palette.sky)
    }

    func inputRow(_ person: Int, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Person.all[person].pronoun)
                .font(.system(size: compact ? 19 : 21, weight: .medium))
                .foregroundStyle(focusedPerson == person ? Palette.blue : Color(white:0.73))
                .frame(width: 88, alignment: .trailing)
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $answers[person])
                        .font(.system(size: compact ? 20 : 22, weight: .medium))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.default)
                        .submitLabel(person == question.people.last ? .done : .next)
                        .focused($focusedPerson, equals: person)
                        .onSubmit { nextField(after: person) }
                        .accessibilityLabel("输入 \(Person.all[person].pronoun) 的变位")
                        .accessibilityIdentifier("answer.\(person)")
                        .frame(maxWidth: .infinity)
                    if focusedPerson == person {
                        Button { replicateAnswer(from: person) } label: {
                            HStack(spacing: 3) {
                                Image.appSymbol( "doc.on.doc").font(.system(size: 11, weight: .semibold))
                                Text("复粘").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Palette.blue)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .frame(minHeight: 28)
                            .background(Palette.sky, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("复粘")
                        .appAccessibilityHint("将当前内容填入本题其他人称的输入框", label: "复粘")
                        .accessibilityIdentifier("replicateAnswer")
                    }
                }
                Rectangle().fill(focusedPerson == person ? Palette.blue.opacity(0.65) : Color(white:0.85)).frame(height:0.5)
            }.frame(maxWidth: .infinity)
        }.frame(minHeight: compact ? 34 : 44).padding(.trailing, 36).padding(.leading, 4)
    }

    func feedbackRow(_ person: Int) -> some View {
        let correct = results[person] == true
        let accepted = question.verb.answers(question.tense, person: person)
        return HStack(alignment: .top, spacing: 10) {
            Text(Person.all[person].pronoun)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(correct ? Color(white:0.73) : Palette.coral)
                .frame(width: 88, alignment: .trailing)
            VStack(alignment: .leading, spacing: 0) {
                if correct {
                    Text(answers[person].trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 22, weight: .medium)).foregroundStyle(.black)
                } else {
                    Text(answers[person].isEmpty ? "未填写" : answers[person])
                        .font(.system(size: 20)).foregroundStyle(Color(white:0.73)).strikethrough(color: Palette.coral.opacity(0.65))
                    Text(accepted.first ?? "—")
                        .font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.coral)
                        .accessibilityIdentifier("correction.\(person)")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if correct {
                Image.appSymbol( "checkmark").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.blue)
                    .accessibilityIdentifier("correct.\(person)")
            }
        }
        .frame(minHeight: 48, alignment: .top).padding(.trailing,36).padding(.leading,4)
        .padding(.vertical, 2)
    }

    var actionButtons: some View {
        HStack(spacing: 10) {
            if checked {
                PrimaryButton(title: "重试", icon: "arrow.triangle.2.circlepath") { retry() }
                    .accessibilityIdentifier("retryQuestion")
                PrimaryButton(title: index == session.questions.count - 1 ? "完成" : "下一页", icon: "play.fill") { nextQuestion() }
                    .accessibilityIdentifier("nextQuestion")
            } else {
                Spacer(minLength: 20)
                PrimaryButton(title: "确定") { check() }.accessibilityIdentifier("checkAnswers")
                Spacer(minLength: 20)
            }
        }
    }

    func nextField(after person: Int) {
        guard let offset = question.people.firstIndex(of: person) else { return }
        if offset + 1 < question.people.count { focusedPerson = question.people[offset + 1] }
        else { check() }
    }

    func replicateAnswer(from person: Int) {
        let text = answers[person]
        var updated = answers
        for other in question.people where other != person {
            updated[other] = text
        }
        answers = updated
        focusedPerson = person
    }

    func check() {
        guard !checked else { return }
        focusedPerson = nil
        var evaluated: [Int: Bool] = [:]
        for person in question.people {
            evaluated[person] = AnswerChecker.matches(answers[person], accepted: question.verb.answers(question.tense, person: person),
                                                      person: person, ignoreAccents: store.settings.ignoreAccents)
        }
        results = evaluated
        if !recorded.contains(question.id) {
            store.record(question: question, results: evaluated, helped: helped.contains(question.id))
            firstResults[question.id] = evaluated
            recorded.insert(question.id)
        } else if evaluated.values.allSatisfy({ $0 }) && !helped.contains(question.id) {
            store.mistakes.remove(question.id)
        }
        checked = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        if store.settings.playAfterCheck { readAnswers() }
    }

    func retry() {
        speaker.stop()
        answers = Array(repeating: "", count: 6)
        results = [:]
        checked = false
        focusFirst()
    }

    func nextQuestion() {
        speaker.stop()
        if index + 1 == session.questions.count { finished = true; return }
        index += 1
        answers = Array(repeating: "", count: 6)
        results = [:]
        checked = false
        showMeaning = false
        focusFirst()
    }

    func focusFirst() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if !checked && !finished { focusedPerson = question.people.first }
        }
    }

    func readAnswers() {
        let phrases = question.people.compactMap { person -> String? in
            guard let answer = question.verb.answers(question.tense, person: person).first else { return nil }
            if question.tense.mood == .imperative { return answer }
            let pronoun = ["je", "tu", "il", "nous", "vous", "ils"][person]
            if person == 0, "aàâeéèêëiîïoôuûüyœ".contains(answer.first ?? " ") { return "j'" + answer }
            return pronoun + " " + answer
        }
        speaker.speak(phrases.joined(separator: ". "))
    }

    var summary: some View {
        let total = firstResults.values.reduce(0) { $0 + $1.count }
        let correct = firstResults.filter { !helped.contains($0.key) }.values.reduce(0) { $0 + $1.values.filter { $0 }.count }
        return VStack(spacing: 24) {
            Spacer()
            Image.appSymbol( "checkmark.circle").font(.system(size: 72, weight: .light)).foregroundStyle(Palette.blue)
            Text("本轮练习完成").font(.system(size: 28, weight: .bold))
            Text(session.title).font(.title3).foregroundStyle(.secondary)
            Text("\(correct) / \(total)").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(Palette.blue)
            Text("首次作答正确的人称数").font(.subheadline).foregroundStyle(.secondary)
            Text("错题已自动加入复习。\n查看答案的题目不计入正确数。")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
            Spacer()
            PrimaryButton(title: "返回动词单") { dismiss() }.padding(.horizontal, 52).padding(.bottom, 45)
                .accessibilityIdentifier("finishSession")
        }.frame(maxWidth: .infinity).background(Palette.sky)
    }
}
