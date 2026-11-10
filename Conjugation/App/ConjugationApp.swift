import SwiftUI

@main
struct ConjugationApp: App {
    @StateObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-state-for-testing") {
            DiagnosticLogStore.shared.clear()
        }
        #endif
        _store = StateObject(wrappedValue: AppStore())
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-diagnostic-logs") {
            DiagnosticLogStore.shared.record(.warning, category: "界面测试", message: "UI_DIAGNOSTIC_WARNING")
            DiagnosticLogStore.shared.record(.error, category: "界面测试", message: "UI_DIAGNOSTIC_ERROR",
                                            details: "DiagnosticsUITests (42): 导出与详情测试")
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .tint(Palette.blue)
                .preferredColorScheme(.light)
                .onAppear { RuntimeLogCollector.shared.resume() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { RuntimeLogCollector.shared.resume() }
                    else if phase == .background { RuntimeLogCollector.shared.pause() }
                }
        }
    }
}
