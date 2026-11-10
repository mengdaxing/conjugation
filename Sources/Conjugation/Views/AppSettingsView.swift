import SwiftUI

struct AppSettingsView: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @Environment(\.dismiss) var dismiss
    @State var resetConfirmation = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("每日正确 \(store.settings.dailyGoal) 次", value: Binding(get: { store.settings.dailyGoal }, set: { store.settings.dailyGoal = $0 }), in: 1...100)
                    Picker("每轮题数", selection: Binding(get: { store.settings.sessionLength }, set: { store.settings.sessionLength = $0 })) {
                        Text("5 组").tag(5)
                        Text("10 组").tag(10)
                        Text("20 组").tag(20)
                        Text("全部已选").tag(0)
                    }
                } header: { Text("学习目标") } footer: {
                    Text("每个人称的一次正确作答计 1 次；查看答案后和同题重试不重复计入目标。")
                }
                Section {
                    Toggle("随机题目顺序", isOn: Binding(get: { store.settings.randomOrder }, set: { store.settings.randomOrder = $0 }))
                    Toggle("每组随机一个已选人称", isOn: Binding(get: { store.settings.randomPerson }, set: { store.settings.randomPerson = $0 }))
                    Toggle("忽略重音符号", isOn: Binding(get: { store.settings.ignoreAccents }, set: { store.settings.ignoreAccents = $0 }))
                    Toggle("提交后自动朗读", isOn: Binding(get: { store.settings.playAfterCheck }, set: { store.settings.playAfterCheck = $0 }))
                } header: { Text("练习方式") } footer: {
                    Text("默认严格检查重音。法语朗读使用设备的系统语音；在系统设置中安装离线法语语音后，无网络时也可使用。")
                }
                Section("你的学习") {
                    LabeledContent("累计正确", value: "\(store.totalCorrect) 次")
                    LabeledContent("连续练习", value: "\(store.streak) 天")
                    LabeledContent("收藏", value: "\(store.favorites.count) 个动词")
                    Button("清除学习记录", role: .destructive) { resetConfirmation = true }
                }
                Section("关于") {
                    LabeledContent("MyConju", value: "1.0.0")
                    Text("776 个动词 · 16 种时态与语式\n词库和学习记录保存在设备本地。")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink("数据来源与开源许可") { CreditsView() }
                }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .confirmationDialog("清除所有成绩和错题记录？", isPresented: $resetConfirmation, titleVisibility: .visible) {
                Button("清除记录", role: .destructive) { store.resetProgress() }
                Button("取消", role: .cancel) {}
            } message: { Text("收藏、动词选择和练习设置会保留。") }
        }
    }
}

struct CreditsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("MyConju").font(.title.bold())
                Text("依据用户提供的界面截图，使用 SwiftUI 独立重建。未包含原应用代码、名称、商标、截图或图片素材。巴黎剪影由代码绘制，应用图标通过内置 imagegen 工具重新设计。")
                Text("变位数据").font(.headline)
                Text("Verbiste 0.1.49\nCopyright © 2003–2024 Pierre Sarrazin\nGNU General Public License v2 or later\n\n本应用将 Verbiste 模板与手工编排的中文词表转换为离线 JSON；原始 XML、转换脚本及完整应用源码随项目提供。其余级别的词表为重新编排，不代表截图中原应用的完整词表。")
                Link("Verbiste 项目", destination: URL(string: "https://sarrazip.com/dev/verbiste.html")!)
                Text("本项目按 GPL-2.0-or-later 提供。完整许可见随包 LICENSE。")
                #if os(Android)
                Text("安卓界面与图标").font(.headline)
                Text("Swift 代码通过 Skip Fuse 编译；界面由 SkipFuseUI / SkipUI 渲染。安卓补充图标来自 Google Material Design Icons，按 Apache-2.0 许可提供。")
                if let url = AppResources.bundle.url(forResource: "MaterialIcons-NOTICE", withExtension: "txt"),
                   let notice = try? String(contentsOf: url, encoding: .utf8) {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
                if let url = AppResources.bundle.url(forResource: "MaterialIcons-LICENSE", withExtension: "txt"),
                   let license = try? String(contentsOf: url, encoding: .utf8) {
                    Text(license).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                #endif
                Text("语法范围").font(.headline)
                Text("收录非代词式动词；无人称和不完全动词只练习有效人称。复合时态在没有上下文时接受所列的助动词与性数变体。词义是便于练习的简要释义。")
                if let url = AppResources.bundle.url(forResource: "LICENSE", withExtension: "txt"),
                   let license = try? String(contentsOf: url, encoding: .utf8) {
                    Text(license).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).appSelectableText(license)
                }
            }.padding(22)
        }.navigationTitle("来源与许可").navigationBarTitleDisplayMode(.inline)
    }
}

struct ProgressViewScreen: View {
    #if os(Android)
    @Environment(AppStore.self) var store: AppStore
    #else
    @EnvironmentObject var store: AppStore
    #endif
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("今天已答对").font(.headline).foregroundStyle(.secondary)
                        Text("\(store.today.correct)").font(.system(size: 66, weight: .bold, design: .rounded)).foregroundStyle(Palette.blue)
                        Text("每日目标 \(store.settings.dailyGoal) 次 · 已完成 \(Int(store.goalProgress * 100))%")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 28)
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(store.recentDays(), id: \.date) { day in
                            VStack(spacing: 8) {
                                Text("\(day.value.correct)").font(.caption.bold()).foregroundStyle(Palette.blue)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Palette.blue)
                                    .frame(height: max(3, 150 * Double(day.value.correct) / Double(max(store.recentDays().map { $0.value.correct }.max() ?? 1,store.settings.dailyGoal))))
                                Text(day.date, format: .dateTime.weekday(.narrow)).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity)
                        }
                    }.frame(height: 210, alignment: .bottom).padding(.horizontal, 20)
                    HStack {
                        statistic("累计正确", "\(store.totalCorrect)")
                        statistic("连续天数", "\(store.streak)")
                        statistic("今日作答", "\(store.today.attempts)")
                    }.padding(.vertical, 24).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    Text("每个人称独立计分。每天练习一点，慢慢掌握每一种变化。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(22)
            }.background(Palette.sky)
                .navigationTitle("学习成绩").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
    func statistic(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 25, weight: .bold)).foregroundStyle(Palette.blue)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}
