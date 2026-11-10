#if os(iOS)
import SwiftUI
import UIKit

struct DiagnosticLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries = DiagnosticLogStore.shared.snapshot()
    @State private var query = ""
    @State private var filter = "all"
    @State private var refreshing = false
    @State private var confirmClear = false
    @State private var exportFile: ExportedDiagnosticFile?
    @State private var exportError = false

    private var filtered: [DiagnosticLogEntry] {
        entries.reversed().filter {
            (filter == "all" || $0.level.rawValue == filter) && $0.matches(query)
        }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("日志级别", selection: $filter) {
                    Text("全部").tag("all")
                    Text("Warning").tag("warning")
                    Text("Error").tag("error")
                }.pickerStyle(.segmented).padding(16).background(Palette.sky)
                if let issue = DiagnosticLogStore.shared.storageIssue {
                    Text(issue).font(.caption).foregroundStyle(Palette.coral).padding(.horizontal,16)
                }
                List {
                    if filtered.isEmpty {
                        EmptyMessage(icon: "doc.text.magnifyingglass",
                                     title: entries.isEmpty ? "暂无错误日志" : "没有匹配的日志",
                                     detail: "出现 warning 或 error 后会自动记录在这里。")
                            .listRowSeparator(.hidden)
                    }
                    ForEach(filtered) { entry in
                        NavigationLink {
                            DiagnosticLogDetailView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(entry.level.title).font(.caption.bold())
                                        .foregroundStyle(entry.level == .error ? Palette.coral : .orange)
                                    Text(entry.category).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    Text(entry.date, format: .dateTime.hour().minute().second())
                                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Text(entry.message).font(.system(size: 15)).lineLimit(3)
                                Text("\(entry.source) · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }.padding(.vertical, 3)
                        }
                    }
                    Section {
                        Text("仅保存 warning / error，最多保留最近 1000 条。系统日志范围限本应用当前进程；答题错误不计入此处。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.listStyle(.plain)
                    .refreshable {
                        await withCheckedContinuation { continuation in
                            RuntimeLogCollector.shared.refresh {
                                reload()
                                continuation.resume()
                            }
                        }
                    }
            }
            .navigationTitle("错误日志").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索消息、模块")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }.accessibilityIdentifier("logsDone")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { refreshing = true; RuntimeLogCollector.shared.refresh { refreshing = false; reload() } } label: {
                        Image.appSymbol( "arrow.clockwise")
                    }.disabled(refreshing).accessibilityLabel("刷新日志")
                    Button(action: export) { Image.appSymbol( "square.and.arrow.up") }
                        .disabled(entries.isEmpty).accessibilityLabel("导出全部日志")
                        .accessibilityIdentifier("exportDiagnosticLogs")
                    Button { confirmClear = true } label: { Image.appSymbol( "trash") }
                        .disabled(entries.isEmpty).accessibilityLabel("清空日志")
                        .accessibilityIdentifier("clearDiagnosticLogs")
                }
            }
            .onAppear { RuntimeLogCollector.shared.refresh { reload() } }
            .onReceive(NotificationCenter.default.publisher(for: .diagnosticLogsChanged)) { _ in reload() }
            .confirmationDialog("清空所有错误日志？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空日志", role: .destructive) { RuntimeLogCollector.shared.clear { reload() } }
                Button("取消", role: .cancel) {}
            } message: { Text("学习记录、收藏和错题不受影响。") }
            .sheet(item: $exportFile) { DiagnosticShareSheet(url: $0.url) }
            .alert("日志导出失败", isPresented: $exportError) { Button("好", role: .cancel) {} }
        }
    }
    private func reload() { entries = DiagnosticLogStore.shared.snapshot() }
    private func export() {
        do { exportFile = ExportedDiagnosticFile(url: try DiagnosticLogStore.shared.export()) }
        catch {
            AppDiagnostics.error("导出错误日志失败", category: "日志导出", error: error)
            exportError = true
        }
    }
}

private struct ExportedDiagnosticFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct DiagnosticShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct DiagnosticLogDetailView: View {
    let entry: DiagnosticLogEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.level.title).font(.title2.bold())
                    .foregroundStyle(entry.level == .error ? Palette.coral : .orange)
                LabeledContent("时间", value: entry.date.formatted(date: .complete, time: .standard))
                LabeledContent("模块", value: entry.category)
                LabeledContent("来源", value: entry.source)
                if !entry.location.isEmpty { Text(entry.location).font(.caption.monospaced()).foregroundStyle(.secondary) }
                Divider()
                Text(entry.message).font(.body).textSelection(.enabled)
                if !entry.details.isEmpty {
                    Text(entry.details).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
        }
        .navigationTitle("日志详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { UIPasteboard.general.string = entry.text } label: {
                    Image.appSymbol( "doc.on.doc")
                }.accessibilityLabel("复制日志详情")
            }
        }
    }
}
#endif
