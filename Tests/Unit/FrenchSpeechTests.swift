import AVFoundation
import XCTest
import UIKit
@testable import Conjugation

@MainActor
final class FrenchSpeechTests: XCTestCase {
    private final class Session: SpeechAudioSession {
        var activations = 0
        var deactivations = 0
        var error: Error?
        func activate() throws {
            activations += 1
            if let error { throw error }
        }
        func deactivate() { deactivations += 1 }
    }

    private final class Engine: FrenchSpeechEngine {
        var onEvent: ((SpeechEvent) -> Void)?
        var spoken: [(text: String, id: UUID)] = []
        var stops = 0
        var error: Error?
        var beforeSpeak: (() -> Void)?
        func speak(_ text: String, id: UUID) throws {
            beforeSpeak?()
            if let error { throw error }
            spoken.append((text, id))
        }
        func stop() -> Bool { stops += 1; return !spoken.isEmpty }
    }

    func testActivatesBeforeSpeakingAndReusesEngineAfterCompletion() {
        let session = Session(), engine = Engine()
        var creations = 0
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { creations += 1; return engine }, observeSystemEvents: false)
        engine.beforeSpeak = { XCTAssertGreaterThan(session.activations, 0) }
        let owner = UUID()
        playback.speak("  bonjour \n", owner: owner) { XCTFail($0) }
        XCTAssertEqual(engine.spoken.first?.text, "bonjour")
        XCTAssertEqual(engine.stops, 0, "First playback must not cancel an idle synthesizer")
        engine.onEvent?(.started(engine.spoken[0].id))
        engine.onEvent?(.ended(engine.spoken[0].id))
        XCTAssertEqual(session.deactivations, 1)
        playback.speak("salut", owner: owner) { XCTFail($0) }
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(engine.spoken.count, 2)
        engine.onEvent?(.ended(engine.spoken[1].id))
        XCTAssertEqual(session.deactivations, 2)
    }

    func testRapidReplacementWaitsForCancellationAndOnlySpeaksLatest() {
        let session = Session(), engine = Engine()
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, observeSystemEvents: false)
        let owner = UUID()
        playback.speak("premier", owner: owner) { XCTFail($0) }
        let first = engine.spoken[0].id
        playback.speak("deuxième", owner: owner) { XCTFail($0) }
        playback.speak("troisième", owner: owner) { XCTFail($0) }
        XCTAssertEqual(engine.spoken.count, 1)
        XCTAssertEqual(engine.stops, 1)
        XCTAssertEqual(session.deactivations, 0)
        engine.onEvent?(.ended(first))
        XCTAssertEqual(engine.spoken.map(\.text), ["premier", "troisième"])
        // A delayed callback from the cancelled utterance cannot finish its replacement.
        engine.onEvent?(.ended(first))
        XCTAssertEqual(session.deactivations, 0)
        engine.onEvent?(.ended(engine.spoken[1].id))
        XCTAssertEqual(session.deactivations, 1)
    }

    func testViewOwnershipAndStopDiscardPendingReplacement() {
        let session = Session(), engine = Engine()
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, observeSystemEvents: false)
        let practice = UUID(), sheet = UUID()
        playback.speak("pratique", owner: practice) { XCTFail($0) }
        playback.speak("référence", owner: sheet) { XCTFail($0) }
        playback.stop(owner: practice)
        engine.onEvent?(.ended(engine.spoken[0].id))
        XCTAssertEqual(engine.spoken.last?.text, "référence")
        playback.speak("autre", owner: sheet) { XCTFail($0) }
        playback.stop(owner: sheet)
        engine.onEvent?(.ended(engine.spoken[1].id))
        XCTAssertEqual(engine.spoken.count, 2)
        XCTAssertEqual(session.deactivations, 1)
    }

    func testActivationFailureIsReportedAndNextTapCanRecover() {
        let session = Session(), engine = Engine()
        session.error = NSError(domain: "SpeechSessionTest", code: -66748)
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, observeSystemEvents: false)
        let speaker = FrenchSpeaker(playback: playback)
        speaker.speak("bonjour")
        XCTAssertNotNil(speaker.errorMessage)
        XCTAssertTrue(engine.spoken.isEmpty)
        session.error = nil
        speaker.speak("bonjour")
        XCTAssertNil(speaker.errorMessage)
        XCTAssertEqual(engine.spoken.count, 1)
        engine.onEvent?(.ended(engine.spoken[0].id))
    }

    func testVoiceFailureReleasesSessionAndShowsActionableMessage() {
        let session = Session(), engine = Engine()
        engine.error = NSError(domain: "SpeechVoiceTest", code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "请下载法语语音"])
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, observeSystemEvents: false)
        let speaker = FrenchSpeaker(playback: playback)
        speaker.speak("bonjour")
        XCTAssertEqual(speaker.errorMessage, "请下载法语语音")
        XCTAssertEqual(session.deactivations, 1)
        XCTAssertTrue(engine.spoken.isEmpty)
    }

    func testMissingCancellationCallbackRebuildsEngineForLatestRequest() async {
        let session = Session(), first = Engine(), second = Engine()
        var creations = 0
        let resumed = expectation(description: "Latest request starts with a fresh engine")
        second.beforeSpeak = { resumed.fulfill() }
        let playback = FrenchSpeechPlayback(session: session, makeEngine: {
            creations += 1
            return creations == 1 ? first : second
        }, cancellationTimeout: 20_000_000, observeSystemEvents: false)
        let owner = UUID()
        playback.speak("premier", owner: owner) { XCTFail($0) }
        playback.speak("dernier", owner: owner) { XCTFail($0) }
        await fulfillment(of: [resumed], timeout: 2)
        XCTAssertEqual(second.spoken.first?.text, "dernier")
        XCTAssertEqual(creations, 2)
        second.onEvent?(.ended(second.spoken[0].id))
    }

    func testStartupTimeoutRetriesOnceThenReportsFailure() async {
        let session = Session()
        var engines: [Engine] = []
        let failed = expectation(description: "Persistent service failure is reported")
        let playback = FrenchSpeechPlayback(session: session, makeEngine: {
            let engine = Engine()
            engines.append(engine)
            return engine
        }, startupTimeout: 20_000_000, observeSystemEvents: false)
        playback.speak("bonjour", owner: UUID()) { _ in failed.fulfill() }
        await fulfillment(of: [failed], timeout: 2)
        XCTAssertEqual(engines.count, 2, "Recovery must be bounded to one retry")
        XCTAssertEqual(engines.map { $0.spoken.count }, [1, 1])
        XCTAssertEqual(session.deactivations, 1)
    }

    func testStopDuringMissingCancellationDoesNotRestartSpeech() async {
        let session = Session(), engine = Engine()
        let released = expectation(description: "Stop timeout completes")
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, cancellationTimeout: 20_000_000, observeSystemEvents: false)
        let owner = UUID()
        playback.speak("bonjour", owner: owner) { XCTFail($0) }
        playback.speak("salut", owner: owner) { XCTFail($0) }
        playback.stop(owner: owner)
        // A bounded async delay allows the no-callback cancellation path to settle.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            released.fulfill()
        }
        await fulfillment(of: [released], timeout: 2)
        XCTAssertEqual(engine.spoken.count, 1)
        XCTAssertEqual(session.deactivations, 1)
    }

    func testMediaServicesResetDoesNotAutoplayAndNextTapRebuilds() {
        let session = Session(), first = Engine(), second = Engine()
        var creations = 0, failures = 0
        let playback = FrenchSpeechPlayback(session: session, makeEngine: {
            creations += 1
            return creations == 1 ? first : second
        }, observeSystemEvents: false)
        let owner = UUID()
        playback.speak("bonjour", owner: owner) { _ in failures += 1 }
        let staleCallback = first.onEvent
        playback.mediaServicesReset()
        XCTAssertEqual(failures, 1)
        XCTAssertEqual(creations, 1)
        XCTAssertEqual(session.deactivations, 0)
        playback.speak("salut", owner: owner) { XCTFail($0) }
        staleCallback?(.ended(first.spoken[0].id))
        XCTAssertEqual(second.spoken.first?.text, "salut")
        XCTAssertEqual(session.deactivations, 0)
        second.onEvent?(.ended(second.spoken[0].id))
        XCTAssertEqual(session.activations, 2)
        XCTAssertEqual(session.deactivations, 1)
    }

    func testEmptyTextDoesNotActivateAudio() {
        let session = Session(), engine = Engine()
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine }, observeSystemEvents: false)
        playback.speak(" \n ", owner: UUID()) { XCTFail($0) }
        XCTAssertEqual(session.activations, 0)
        XCTAssertTrue(engine.spoken.isEmpty)
    }

    func testInterruptionStopsWithoutAutoplayAndAllowsNextUserRequest() {
        let session = Session(), first = Engine(), second = Engine()
        var creations = 0
        let playback = FrenchSpeechPlayback(session: session, makeEngine: {
            creations += 1
            return creations == 1 ? first : second
        })
        let owner = UUID()
        playback.speak("bonjour", owner: owner) { XCTFail($0) }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertNil(first.onEvent)
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        XCTAssertTrue(second.spoken.isEmpty)
        playback.speak("salut", owner: owner) { XCTFail($0) }
        XCTAssertEqual(second.spoken.first?.text, "salut")
        second.onEvent?(.ended(second.spoken[0].id))
    }

    func testBackgroundCancelsSpeechAndReleasesAudioAfterCompletion() {
        let session = Session(), engine = Engine()
        let playback = FrenchSpeechPlayback(session: session, makeEngine: { engine })
        playback.speak("bonjour", owner: UUID()) { XCTFail($0) }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(engine.stops, 1)
        XCTAssertEqual(session.deactivations, 0)
        engine.onEvent?(.ended(engine.spoken[0].id))
        XCTAssertEqual(session.deactivations, 1)
        XCTAssertEqual(engine.spoken.count, 1)
    }

    func testSystemEngineCanSpeakFrenchTwiceWithPlaybackSession() async throws {
        guard AVSpeechSynthesisVoice(language: "fr-FR") != nil else {
            throw XCTSkip("This simulator has no French voice installed")
        }
        let session = SystemSpeechAudioSession(), engine = SystemFrenchSpeechEngine()
        try session.activate()
        defer { engine.stop(); try? session.deactivate() }
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertEqual(AVAudioSession.sharedInstance().mode, .spokenAudio)
        for text in ["bonjour", "salut"] {
            let started = expectation(description: "French utterance starts: \(text)")
            let finished = expectation(description: "French utterance finishes: \(text)")
            let id = UUID()
            engine.onEvent = { event in
                switch event {
                case .started(let eventID) where eventID == id: started.fulfill()
                case .ended(let eventID) where eventID == id: finished.fulfill()
                default: break
                }
            }
            try engine.speak(text, id: id)
            await fulfillment(of: [started, finished], timeout: 20, enforceOrder: true)
        }
    }
}
