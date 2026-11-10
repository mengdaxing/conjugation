#if !os(Android)
import AVFoundation
import Combine
#if os(iOS)
import UIKit
#endif

/// Views own a playback lease, while the app retains one system synthesizer.
/// A disappearing sheet must not stop speech started by another view.
@MainActor
final class FrenchSpeaker: ObservableObject {
    @Published var errorMessage: String?
    private let owner = UUID()
    private let playback: FrenchSpeechPlayback

    init(playback: FrenchSpeechPlayback? = nil) { self.playback = playback ?? .shared }

    func speak(_ text: String) {
        errorMessage = nil
        playback.speak(text, owner: owner) { [weak self] in self?.errorMessage = $0 }
    }

    func stop() { playback.stop(owner: owner) }
}

enum SpeechEvent {
    case started(UUID), ended(UUID)
}

@MainActor
protocol FrenchSpeechEngine: AnyObject {
    var onEvent: ((SpeechEvent) -> Void)? { get set }
    func speak(_ text: String, id: UUID) throws
    @discardableResult func stop() -> Bool
}

@MainActor
protocol SpeechAudioSession {
    func activate() throws
    func deactivate() throws
}

struct SystemSpeechAudioSession: SpeechAudioSession {
    func activate() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try session.setActive(true)
        #endif
    }

    func deactivate() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

@MainActor
final class SystemFrenchSpeechEngine: NSObject, FrenchSpeechEngine, AVSpeechSynthesizerDelegate {
    var onEvent: ((SpeechEvent) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (utterance: AVSpeechUtterance, id: UUID)?

    override init() {
        super.init()
        #if os(iOS)
        synthesizer.usesApplicationAudioSession = true
        #endif
        synthesizer.delegate = self
    }

    func speak(_ text: String, id: UUID) throws {
        // Never silently substitute a non-French voice for a language exercise.
        guard let voice = AVSpeechSynthesisVoice(language: "fr-FR") else {
            throw SpeechFailure("设备没有可用的法语语音。请在系统设置的“辅助功能”语音设置中下载法语语音后重试。")
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.40
        current = (utterance, id)
        synthesizer.speak(utterance)
    }

    @discardableResult func stop() -> Bool { synthesizer.stopSpeaking(at: .immediate) }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, let current = self.current, current.utterance === utterance else { return }
            self.onEvent?(.started(current.id))
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.ended(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.ended(utterance) }
    }

    private func ended(_ utterance: AVSpeechUtterance) {
        guard let current, current.utterance === utterance else { return }
        self.current = nil
        onEvent?(.ended(current.id))
    }
}

private struct SpeechFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Serialize cancellation and replacement: stopSpeaking is not a synchronous
/// teardown barrier, and unspoken utterances may never produce didCancel.
@MainActor
final class FrenchSpeechPlayback: NSObject {
    static let shared = FrenchSpeechPlayback()

    private struct Request {
        let owner: UUID
        let text: String
        let onFailure: (String) -> Void
        var retries = 0
    }

    private let session: SpeechAudioSession
    private let makeEngine: @MainActor () -> FrenchSpeechEngine
    private let startupTimeout: UInt64
    private let cancellationTimeout: UInt64
    private var engine: FrenchSpeechEngine?
    private var request: Request?
    private var currentID: UUID?
    private var stopping = false
    private var sessionActive = false
    private var deadline: Task<Void, Never>?

    init(session: SpeechAudioSession? = nil,
         makeEngine: @escaping @MainActor () -> FrenchSpeechEngine = { SystemFrenchSpeechEngine() },
         startupTimeout: UInt64 = 8_000_000_000,
         cancellationTimeout: UInt64 = 1_000_000_000,
         observeSystemEvents: Bool = true) {
        self.session = session ?? SystemSpeechAudioSession()
        self.makeEngine = makeEngine
        self.startupTimeout = startupTimeout
        self.cancellationTimeout = cancellationTimeout
        super.init()
        #if os(iOS)
        if observeSystemEvents {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(mediaServicesReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
            center.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
            center.addObserver(self, selector: #selector(stopForBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        #endif
    }

    deinit { deadline?.cancel() }

    func speak(_ text: String, owner: UUID, onFailure: @escaping (String) -> Void) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        request = Request(owner: owner, text: text, onFailure: onFailure)
        if currentID != nil { cancelCurrent() }
        else { startLatest() }
    }

    func stop(owner: UUID) {
        guard request?.owner == owner else { return }
        request = nil
        if currentID != nil { cancelCurrent() }
        else { releaseSession() }
    }

    private func cancelCurrent() {
        guard !stopping else { return }
        stopping = true
        deadline?.cancel()
        // Keep the engine alive until cancellation completes. A timeout also
        // handles queued utterances, for which Apple does not promise didCancel.
        armDeadline(after: cancellationTimeout) { [weak self] in
            self?.discardEngine()
            self?.startLatest()
        }
        engine?.stop()
    }

    private func startLatest() {
        deadline?.cancel()
        guard let request else { releaseSession(); return }
        do {
            try session.activate()
            sessionActive = true
        } catch {
            fail("无法启用音频播放，请结束通话或其他音频操作后再次点击朗读。", error: error)
            return
        }
        do {
            if engine == nil {
                let newEngine = makeEngine()
                newEngine.onEvent = { [weak self] event in self?.handle(event) }
                engine = newEngine
            }
            let id = UUID()
            currentID = id
            stopping = false
            armDeadline(after: startupTimeout) { [weak self] in self?.startupFailed() }
            try engine?.speak(request.text, id: id)
        } catch {
            fail(error.localizedDescription, error: error)
        }
    }

    private func handle(_ event: SpeechEvent) {
        switch event {
        case .started(let id):
            guard id == currentID, !stopping else { return }
            deadline?.cancel()
        case .ended(let id):
            guard id == currentID else { return }
            deadline?.cancel()
            currentID = nil
            if stopping {
                stopping = false
                startLatest()
            } else {
                request = nil
                releaseSession()
            }
        }
    }

    private func startupFailed() {
        guard let current = request else { return }
        discardEngine()
        if current.retries == 0 {
            AppDiagnostics.warning("系统朗读未启动，重建语音引擎后重试一次", category: "法语朗读")
            request?.retries += 1
            startLatest()
        } else {
            fail("系统语音服务暂时不可用，请稍后再次点击朗读。如果仍无法播放，请确认已下载法语语音，并尝试重启应用。")
        }
    }

    private func armDeadline(after delay: UInt64, action: @escaping @MainActor () -> Void) {
        deadline?.cancel()
        deadline = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: delay) }
            catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func discardEngine() {
        deadline?.cancel()
        engine?.onEvent = nil
        engine?.stop()
        engine = nil
        currentID = nil
        stopping = false
    }

    private func fail(_ message: String, error: Error? = nil) {
        let onFailure = request?.onFailure
        request = nil
        discardEngine()
        releaseSession()
        AppDiagnostics.error(message, category: "法语朗读", error: error)
        onFailure?(message)
    }

    private func releaseSession() {
        guard sessionActive else { return }
        sessionActive = false
        do { try session.deactivate() }
        catch { AppDiagnostics.warning("释放朗读音频会话失败", category: "法语朗读", error: error) }
    }

    @objc func mediaServicesReset() {
        let onFailure = request?.onFailure
        request = nil
        sessionActive = false // The system already discarded the old session.
        discardEngine()
        AppDiagnostics.warning("系统音频服务已重启，下一次朗读将重新配置音频", category: "法语朗读")
        onFailure?("系统音频服务已重启，请再次点击朗读。")
    }

    #if os(iOS)
    @objc private func interrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        request = nil
        sessionActive = false
        discardEngine()
    }

    @objc private func stopForBackground() {
        guard let owner = request?.owner else { return }
        stop(owner: owner)
    }
    #endif
}
#endif
