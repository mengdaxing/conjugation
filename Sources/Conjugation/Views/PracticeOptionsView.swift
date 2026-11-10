import SwiftUI

struct PracticeOptionsView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @Environment(\.dismiss) var dismiss
    var initialTab = 0
    @State var tab = 0
    @State var help: Tense?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("练习设置").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("完成") { dismiss() }.font(.headline).accessibilityIdentifier("optionsDone")
            }.padding(.horizontal, 18).padding(.top, 20)
            Text(tab == 0 ? "练习的时态" : "主词代名词")
                .font(.system(size: 25, weight: .bold)).frame(maxWidth: .infinity)
                .padding(.top, 47).padding(.bottom, 60).background(Palette.sky)
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: PlatformLayout.pinnedHeaders) {
                    if tab == 0 { tenseContent } else { peopleContent }
                }
            }.background(.white)
            Picker("设置页面", selection: $tab) {
                AppLabel(title: "时态", systemImage: "clock").tag(0)
                AppLabel(title: "主词代名词", systemImage: "person.2").tag(1)
            }.pickerStyle(.segmented).padding(14).background(.white)
                .accessibilityIdentifier("optionsTabs")
        }
        .background(Palette.sky)
        .onAppear { tab = initialTab }
        .sheet(item: $help) { TenseHelpView(tense: $0) }
    }

    var tenseContent: some View {
        ForEach(Mood.allCases) { mood in
            Section {
                ForEach(Tense.allCases.filter { $0.mood == mood }) { tense in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tense.title).font(.system(size: 19, weight: .bold))
                                Text(tense.chinese).font(.system(size: 15, weight: .medium))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button { help = tense } label: {
                                Image.appSymbol( "book").font(.system(size: 22, weight: .light))
                            }.accessibilityLabel("\(tense.chinese)说明")
                            Toggle(tense.chinese, isOn: Binding(
                                get: { store.settings.selectedTenses.contains(tense) },
                                set: { selected in
                                    if selected { store.settings.selectedTenses.insert(tense) }
                                    else if store.settings.selectedTenses.count > 1 { store.settings.selectedTenses.remove(tense) }
                                }
                            )).labelsHidden().tint(Palette.yellow)
                                .accessibilityIdentifier("tense.\(tense.rawValue)")
                        }.padding(.horizontal, 16).padding(.vertical, 13)
                        Divider().padding(.leading, 16)
                    }
                }
            } header: {
                HStack {
                    Text(mood.title).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.blue)
                    Spacer()
                    Text(mood.chinese).font(.system(size: 15, weight: .semibold)).foregroundStyle(.gray)
                }.padding(.horizontal, 16).padding(.vertical, 5).background(Palette.sky)
            }
        }
    }

    var peopleContent: some View {
        VStack(spacing: 0) {
            optionBand("测验顺序")
            Picker("测验顺序", selection: Binding(get: { store.settings.randomOrder }, set: { store.settings.randomOrder = $0 })) {
                AppLabel(title: "依序", systemImage: "list.number").tag(false)
                AppLabel(title: "随机", systemImage: "shuffle").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
            optionBand("测验代名词")
            Picker("测验代名词", selection: Binding(get: { store.settings.randomPerson }, set: { store.settings.randomPerson = $0 })) {
                AppLabel(title: "所有已选", systemImage: "switch.2").tag(false)
                AppLabel(title: "随机一个", systemImage: "dice").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
            optionBand("已选代名词")
            ForEach(Person.all) { person in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.title).font(.system(size: 18, weight: .bold)).minimumScaleFactor(0.75)
                            Text(person.detail).font(.system(size: 15, weight: .medium))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Toggle(person.title, isOn: Binding(
                            get: { store.settings.selectedPeople.contains(person.id) },
                            set: { selected in
                                if selected { store.settings.selectedPeople.insert(person.id) }
                                else if store.settings.selectedPeople.count > 1 { store.settings.selectedPeople.remove(person.id) }
                            }
                        )).labelsHidden().tint(Palette.yellow).accessibilityIdentifier("person.\(person.id)")
                    }.padding(.horizontal, 16).padding(.vertical, 13)
                    Divider().padding(.leading,16)
                }
            }
        }
    }

    func optionBand(_ text: String) -> some View {
        Text(text).font(.system(size: 19, weight: .bold)).foregroundStyle(Palette.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal,16).padding(.vertical, 5).background(Palette.sky)
    }
}

struct TenseHelpView: View {
    let tense: Tense
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(tense.mood.title).font(.headline).foregroundStyle(Palette.blue)
                    Text(tense.title).font(.largeTitle.bold())
                    Text(tense.chinese).font(.title3).foregroundStyle(.secondary)
                    Text(tense.explanation).font(.title3).lineSpacing(7)
                    Divider()
                    Text("填写提示").font(.headline)
                    Text("输入变位后的动词即可，不必重复左侧主语。复合时态需要同时填写助动词和过去分词。\n\n使用 être 的复合时态接受与主语相符的阴性、阳性变体；部分动词按含义可使用 être 或 avoir，系统会接受词库中的两种形式。")
                        .font(.body).foregroundStyle(.secondary).lineSpacing(5)
                }.padding(24)
            }
            .background(Palette.sky.opacity(0.5))
            .navigationTitle("时态说明").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
