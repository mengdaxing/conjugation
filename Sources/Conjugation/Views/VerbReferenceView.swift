import SwiftUI

struct VerbReferenceView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @Environment(\.dismiss) var dismiss
    let verb: Verb
    var initialTense: Tense = .present
    @State var tense: Tense = .present
    #if os(Android)
    @State var speaker = FrenchSpeaker()
    #else
    @StateObject var speaker = FrenchSpeaker()
    #endif
    @State var session: PracticeSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(verb.title).font(.system(size: 34, weight: .bold))
                        Text(verb.meaning).font(.title3).foregroundStyle(.secondary)
                        Button { speaker.speak(verb.id) } label: {
                            AppLabel(title: "法语发音", systemImage: "speaker.wave.2").font(.subheadline)
                        }
                    }.padding(.vertical, 18).frame(maxWidth: .infinity).background(Palette.sky)
                    Picker("时态", selection: $tense) {
                        ForEach(Tense.allCases) { tense in
                            Text("\(tense.mood.title) · \(tense.title)").tag(tense)
                        }
                    }.pickerStyle(.menu).padding(.horizontal, 14)
                    VStack(spacing: 0) {
                        ForEach(Person.all) { person in
                            let answers = verb.answers(tense, person: person.id)
                            HStack(alignment: .top, spacing: 15) {
                                Text(person.pronoun).font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                                Text(answers.isEmpty ? "—" : answers.joined(separator: " / "))
                                    .font(.system(size: 20, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                                    .appSelectableText(answers.isEmpty ? "—" : answers.joined(separator: " / "))
                                if let first = answers.first {
                                    Button { speaker.speak(spoken(person: person.id, answer: first)) } label: {
                                        Image.appSymbol( "speaker.wave.2").font(.system(size: 16))
                                    }.accessibilityLabel("朗读 \(person.pronoun)")
                                }
                            }.padding(.vertical, 13).padding(.horizontal, 18)
                            Divider().padding(.leading, 18)
                        }
                    }
                    Text(tense.explanation).font(.subheadline).lineSpacing(4).foregroundStyle(.secondary).padding(.horizontal,22)
                    PrimaryButton(title: "练习这个动词", icon: "play.fill") {
                        var settings = store.settings
                        settings.selectedTenses = [tense]
                        session = store.startSession(title: verb.title, verbs: [verb], override: settings)
                    }.padding(.horizontal, 22).padding(.vertical, 12).accessibilityIdentifier("practiceVerb")
                }
            }
            .navigationTitle("变位表").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { store.toggleFavorite(verb) } label: {
                        Image.appSymbol( store.favorites.contains(verb.id) ? "star.fill" : "star")
                    }.accessibilityLabel(store.favorites.contains(verb.id) ? "取消收藏" : "收藏动词")
                        .accessibilityIdentifier("favoriteVerb")
                }
            }
            .onAppear { tense = initialTense }
            .onDisappear { speaker.stop() }
            .speechPlaybackAlert(speaker)
            .fullScreenCover(item: $session) { PracticeView(session: $0) }
        }
    }
    func spoken(person: Int, answer: String) -> String {
        if tense.mood == .imperative { return answer }
        return ["je", "tu", "il", "nous", "vous", "ils"][person] + " " + answer
    }
}
