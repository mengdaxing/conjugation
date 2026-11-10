import SwiftUI

struct HomeView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @State var query = ""
    @State var showSettings = false
    @State var showProgress = false
    @State var session: PracticeSession?
    @State var detail: Verb?
    #if os(iOS)
    @State var showLogs = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { dashboard }
                    searchBar
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SectionBand(title: "学习动词单")
                        ForEach(VerbLevel.allCases) { level in
                            NavigationLink {
                                VerbListView(title: level.title, verbs: store.lexicon.verbs.filter { $0.level == level })
                            } label: {
                                menuRow(title: level.title,
                                        subtitle: "\(store.lexicon.verbs.filter { $0.level == level }.count) 个动词")
                            }.buttonStyle(.plain).accessibilityIdentifier("level.\(level.rawValue)")
                        }
                        SectionBand(title: "我的动词单")
                        NavigationLink {
                            VerbListView(title: "优先的", verbs: store.lexicon.verbs.filter { store.favorites.contains($0.id) }, isFavorites: true)
                        } label: {
                            menuRow(title: "优先的", subtitle: store.favorites.isEmpty ? "空" : "\(store.favorites.count) 个动词")
                        }.buttonStyle(.plain)
                        Button {
                            session = store.mistakeSession()
                        } label: {
                            menuRow(title: "错题复习", subtitle: store.mistakes.isEmpty ? "还没有错题" : "\(store.mistakes.count) 组待复习")
                        }.buttonStyle(.plain).disabled(store.mistakes.isEmpty)
                        footer
                    } else {
                        searchResults
                    }
                    if let error = store.lexicon.error {
                        Text(error).foregroundStyle(Palette.coral).padding()
                    }
                }
            }
            .background(Palette.top.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { AppSettingsView() }
            .sheet(isPresented: $showProgress) { ProgressViewScreen() }
            #if os(iOS)
            .sheet(isPresented: $showLogs) { DiagnosticLogsView() }
            #endif
            .sheet(item: $detail) { VerbReferenceView(verb: $0) }
            .fullScreenCover(item: $session) { PracticeView(session: $0) }
        }
    }

    var dashboard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Palette.top, Palette.sky, Color(white:0.98)], startPoint: .top, endPoint: .bottom)
                ParisSkyline().frame(height: 320)
                VStack(spacing: 7) {
                    HStack(alignment: .top) {
                        Spacer().frame(width: 36)
                        VStack(spacing: 5) {
                            Text("每天的目标: \(store.settings.dailyGoal) 正确").font(.system(size: 18, weight: .bold))
                            Text("按柱型图显示成绩").font(.system(size: 14, weight: .semibold))
                        }.frame(maxWidth: .infinity)
                        Button { showSettings = true } label: {
                            Image.appSymbol( "gearshape.fill").font(.system(size: 26)).foregroundStyle(.gray)
                        }.accessibilityLabel("设置").accessibilityIdentifier("settings")
                    }.padding(.horizontal, 18).padding(.top, 24)
                    Spacer()
                    Button { showProgress = true } label: {
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(Palette.coral.opacity(0.21)).frame(width: 32, height: 220)
                            Rectangle().fill(Palette.blue.opacity(0.95))
                                .frame(width: 32, height: max(2, 220 * store.goalProgress))
                            Text("\(store.today.correct)")
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.blue)
                                .offset(x: -5, y: -max(4, 220 * store.goalProgress) - 3)
                        }.frame(width: 74, height: 240)
                    }.buttonStyle(.plain).accessibilityLabel("今天正确 \(store.today.correct) 次，查看成绩")
                }
            }.frame(height: 328)
            Button { showProgress = true } label: {
                VStack(spacing: 0) {
                    Text("\(Int(store.goalProgress * 100))%")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.blue)
                    Text("今天").font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                }.frame(maxWidth: .infinity).padding(.top, 5).padding(.bottom, 10)
            }.buttonStyle(.plain)
        }.background(Color(white: 0.975))
    }

    var searchBar: some View {
        HStack(spacing: 14) {
            Image.appSymbol( "magnifyingglass").font(.system(size: 21)).foregroundStyle(.gray)
            TextField("搜索全部的动词", text: $query)
                .font(.system(size: 20, weight: .semibold))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("verbSearch")
            if !query.isEmpty {
                Button { query = "" } label: { Image.appSymbol( "xmark.circle.fill").foregroundStyle(.gray) }
                    .accessibilityLabel("清除搜索")
            }
        }.padding(.horizontal, 18).frame(height: 52).background(Color(white: 0.975))
    }

    func menuRow(title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 21, weight: .bold)).foregroundStyle(.black)
                    Text(subtitle).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image.appSymbol( "chevron.right").font(.system(size: 21, weight: .bold)).foregroundStyle(Color(white: 0.78))
            }.padding(.horizontal, 20).frame(minHeight: 65)
            Divider().padding(.leading, 20)
        }.background(.white).appContentShape()
    }

    var searchResults: some View {
        let matches = store.lexicon.search(query)
        return VStack(spacing: 0) {
            SectionBand(title: "搜索结果 · \(matches.count)")
            if matches.isEmpty {
                EmptyMessage(icon: "magnifyingglass", title: "没有找到动词", detail: "试试法语不定式或中文释义，也可以省略重音。")
            } else {
                NavigationLink {
                    VerbListView(title: "搜索结果", verbs: matches)
                } label: {
                    AppLabel(title: "练习搜索结果", systemImage: "play.fill").font(.headline)
                        .frame(maxWidth: .infinity).padding(14).foregroundStyle(Palette.blue)
                }
                ForEach(matches) { verb in
                    Button { detail = verb } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verb.title).font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                                Text(verb.meaning).font(.system(size: 16)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.favorites.contains(verb.id) { Image.appSymbol( "star.fill").foregroundStyle(Palette.blue) }
                            Image.appSymbol( "chevron.right").foregroundStyle(.gray)
                        }.padding(.horizontal,20).padding(.vertical,13).appContentShape()
                    }.buttonStyle(.plain).accessibilityIdentifier("search.\(verb.id)")
                    Divider().padding(.leading,20)
                }
            }
        }
    }
    var footer: some View {
        #if os(iOS)
        HStack(spacing: 10) {
            Text("法语动词变位 · 离线练习")
                .font(.footnote).foregroundStyle(.tertiary)
                .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
            Button { showLogs = true } label: {
                AppLabel(title: "错误日志", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.blue)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Palette.sky, in: Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("errorLogsEntry")
        }.padding(.horizontal, 18).padding(.vertical, 20).background(Color(white: 0.98))
        #else
        Text("法语动词变位 · 离线练习")
            .font(.footnote).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity).padding(24).background(Color(white: 0.98))
        #endif
    }
}
