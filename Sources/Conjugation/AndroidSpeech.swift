// This small adapter is transpiled to Kotlin. The application and its UI remain native Swift.
#if SKIP
import Foundation
import android.speech.tts.TextToSpeech
import android.widget.Toast
import java.util.Locale

/* SKIP @bridge */ public final class AndroidSpeechEngine {
    private var engine: TextToSpeech? = nil
    private var ready = false
    private var available = false
    private var pending: String? = nil

    /* SKIP @bridge */ public init() {
        engine = TextToSpeech(ProcessInfo.processInfo.androidContext, { status in
            if status == TextToSpeech.SUCCESS {
                if let tts = self.engine {
                    let result = tts.setLanguage(Locale.FRANCE)
                    self.available = result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED
                    tts.setSpeechRate(Float(0.85))
                    if let voice = tts.getVoices()?.firstOrNull({ $0.getLocale().getLanguage() == "fr" && !$0.isNetworkConnectionRequired() }) {
                        tts.setVoice(voice)
                    }
                }
            }
            self.ready = true
            if let text = self.pending {
                self.pending = nil
                self.speak(text)
            }
        })
    }

    /* SKIP @bridge */ public func speak(_ text: String) {
        if !ready { pending = text; return }
        if available {
            engine?.speak(text, TextToSpeech.QUEUE_FLUSH, nil, "french-verbs")
        } else {
            Toast.makeText(ProcessInfo.processInfo.androidContext, "请先在系统语音设置中安装法语语音", Toast.LENGTH_LONG).show()
        }
    }

    /* SKIP @bridge */ public func stop() { pending = nil; engine?.stop() }
    /* SKIP @bridge */ public func shutdown() { pending = nil; engine?.shutdown(); engine = nil }
}
#endif
