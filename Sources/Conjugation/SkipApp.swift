#if SWIFT_PACKAGE || SKIP
import SwiftUI
import SkipFuse

/// Shared entry point used by the Skip Android launcher.
/* SKIP @bridge */ public struct ConjugationRootView: View {
    #if os(Android)
    @State var store = AppStore()
    #else
    @StateObject var store = AppStore()
    #endif

    /* SKIP @bridge */ public init() {}

    public var body: some View {
        #if os(Android)
        HomeView().environment(store).tint(Palette.blue).preferredColorScheme(.light)
        #else
        HomeView().environmentObject(store).tint(Palette.blue).preferredColorScheme(.light)
        #endif
    }
}

/* SKIP @bridge */ public final class ConjugationAppDelegate: Sendable {
    /* SKIP @bridge */ public static let shared = ConjugationAppDelegate()
    private init() {}
    // SKIP @bridge
    @MainActor public func verifyCore(_ phase: String) -> String {
        #if os(Android) && DEBUG
        return AndroidVerification.run(phase)
        #else
        return "Verification requires an Android debug build"
        #endif
    }
    /* SKIP @bridge */ public func onInit() {}
    /* SKIP @bridge */ public func onLaunch() {}
    /* SKIP @bridge */ public func onResume() {}
    /* SKIP @bridge */ public func onPause() {}
    /* SKIP @bridge */ public func onStop() {}
    /* SKIP @bridge */ public func onDestroy() {}
    /* SKIP @bridge */ public func onLowMemory() {}
}

#endif
