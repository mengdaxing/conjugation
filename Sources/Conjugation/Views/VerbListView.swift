import SwiftUI

struct ScrollPositionKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct VerbListView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    let title: String
    let verbs: [Verb]
    var isFavorites = false
    @State var options = false
    @State var optionsTab = 0
    @State var detail: Verb?
    @State var session: PracticeSession?
    @State var collapsed = false
    @State var noQuestions = false

    var visibleVerbs: [Verb] { isFavorites ? verbs.filter { store.favorites.contains($0.id) } : verbs }
    var selected: [Verb] { visibleVerbs.filter { !store.excluded.contains($0.id) } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: PlatformLayout.pinnedHeaders) {
                #if !os(Android)
                GeometryReader { proxy in
                    Color.clear.preference(key: ScrollPositionKey.self, value: proxy.frame(in: .named("verbs")).minY)
                }.frame(height: 0)
                #endif
                intro
                if visibleVerbs.isEmpty {
                    EmptyMessage(icon: "star", title: "收藏你想练习的动词", detail: "打开任意动词的变位表，点右上角的星标，即可加入这里。")
                }
                ForEach(VerbGroup.allCases) { group in
                    let groupVerbs = visibleVerbs.filter { $0.group == group }
                    if !groupVerbs.isEmpty {
                        Section {
                            ForEach(groupVerbs) { verb in verbRow(verb) }
                        } header: {
                            groupHeader(group, verbs: groupVerbs)
                        }
                    }
                }
            }
        }
        .appVerbListCoordinateSpace()
        .onPreferenceChange(ScrollPositionKey.self) { collapsed = $0 < -240 }
        .background(Color.white)
        .navigationTitle(PlatformLayout.isAndroid ? title : (collapsed ? title : ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.top, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("练习设置", systemImage: "slider.horizontal.3") { options = true }
                    Button("全选动词", systemImage: "checkmark.circle") {
                        for verb in visibleVerbs { store.setSelected(verb, selected: true) }
                    }
                    Button("取消全部", systemImage: "circle") {
                        for verb in visibleVerbs { store.setSelected(verb, selected: false) }
                    }
                } label: {
                    Image.appSymbol( "ellipsis.circle.fill").font(.system(size: 25))
                }.accessibilityLabel("动词单选项")
            }
        }
        .appTopInset {
            if PlatformLayout.isAndroid || collapsed {
                PrimaryButton(title: "开始练习", action: start)
                    .accessibilityIdentifier(PlatformLayout.isAndroid ? "startPractice" : "startPracticeCompact")
                    .disabled(selected.isEmpty)
                    .padding(.horizontal, 20).padding(.bottom, 4).background(Palette.top)
            }
        }
        .sheet(isPresented: $options) { PracticeOptionsView(initialTab: optionsTab) }
        .sheet(item: $detail) { VerbReferenceView(verb: $0) }
        .fullScreenCover(item: $session) { PracticeView(session: $0) }
        .alert("暂时没有可以练习的题目", isPresented: $noQuestions) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请至少选择一个动词、时态和适用的人称。命令式只支持 tu、nous、vous。")
        }
    }

    var intro: some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 26, weight: .bold)).padding(.top, 26)
            Text("\(selected.count) 动词").font(.system(size: 19, weight: .medium)).padding(.top, 8)
            HStack(spacing: 0) {
                Button {
                    optionsTab = 0; options = true
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("时态").font(.system(size: 20, weight: .bold))
                        Text("\(store.settings.selectedTenses.count) 选择了").font(.system(size: 17, weight: .medium))
                    }.padding(.horizontal, 12).frame(minHeight: 50)
                }.accessibilityIdentifier("tenseOptions")
                Rectangle().fill(Color(white: 0.88)).frame(width: 3)
                Button {
                    optionsTab = 1; options = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("主词代名词").font(.system(size: 20, weight: .bold))
                            Text(peopleSummary).font(.system(size: 16, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 2)
                        Image.appSymbol( "chevron.right").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(white: 0.77))
                    }.padding(.horizontal, 10)
                }.accessibilityIdentifier("personOptions")
            }
            .foregroundStyle(.black).frame(height: 52).background(.white, in: RoundedRectangle(cornerRadius: 9))
            .cardShadow().padding(.top, 43)
            #if !os(Android)
            PrimaryButton(title: "开始练习", action: start)
                .accessibilityIdentifier("startPractice")
                .disabled(selected.isEmpty).opacity(selected.isEmpty ? 0.45 : 1)
                .padding(.top, 20).padding(.bottom, 58)
            #else
            Spacer().frame(height: 24)
            #endif
        }
        .padding(.horizontal, 20)
        .background(LinearGradient(colors: [Palette.top,Palette.sky, Color(white:0.98)], startPoint: .top, endPoint: .bottom))
    }

    var peopleSummary: String {
        ["je", "tu", "il", "nous", "vous", "ils"].enumerated()
            .filter { store.settings.selectedPeople.contains($0.offset) }.map(\.element).joined(separator: ", ")
    }

    func groupHeader(_ group: VerbGroup, verbs: [Verb]) -> some View {
        let allSelected = verbs.allSatisfy { !store.excluded.contains($0.id) }
        return HStack {
            Text(group.title).font(.system(size: 23, weight: .bold))
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(verbs.count) 动词").font(.system(size: 18, weight: .semibold))
                Button(allSelected ? "取消全部" : "选择全部") {
                    for verb in verbs { store.setSelected(verb, selected: !allSelected) }
                }.font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.blue)
            }
        }.padding(.horizontal, 20).padding(.vertical, 9)
            .frame(maxWidth: .infinity).background(Palette.sky)
    }

    func verbRow(_ verb: Verb) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { detail = verb } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(verb.title).font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
                            if store.favorites.contains(verb.id) {
                                Image.appSymbol( "star.fill").font(.caption).foregroundStyle(Palette.blue)
                            }
                        }
                        verbMeaning(verb)
                            .font(.system(size: 17, weight: .medium)).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).appContentShape()
                }.buttonStyle(.plain).accessibilityIdentifier("verb.\(verb.id)")
                Toggle("选择 \(verb.id)", isOn: Binding(
                    get: { !store.excluded.contains(verb.id) },
                    set: { store.setSelected(verb, selected: $0) }
                )).labelsHidden().tint(Palette.blue).accessibilityIdentifier("select.\(verb.id)")
            }.padding(.horizontal, 20).frame(minHeight: 64)
            Divider().padding(.leading, 20)
        }.background(.white)
    }

    @ViewBuilder
    func verbMeaning(_ verb: Verb) -> some View {
        #if os(Android)
        HStack(alignment: .top, spacing: 0) {
            if verb.group == .irregular { Text("irrégulier / ").foregroundStyle(Palette.coral) }
            Text(verb.meaning).foregroundStyle(Palette.text)
        }
        #else
        Text(verb.group == .irregular ? "irrégulier / " : "").foregroundColor(Palette.coral)
            + Text(verb.meaning).foregroundColor(Palette.text)
        #endif
    }

    func start() {
        session = store.startSession(title: title, verbs: selected)
        noQuestions = session == nil
    }
}
