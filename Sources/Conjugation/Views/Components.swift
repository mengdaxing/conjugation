import SwiftUI

enum Palette {
    static let blue = Color(red: 0.22, green: 0.76, blue: 0.97)
    static let sky = Color(red: 0.91, green: 0.97, blue: 0.99)
    static let top = Color(red: 0.85, green: 0.97, blue: 0.99)
    static let coral = Color(red: 1, green: 0.32, blue: 0.45)
    static let yellow = Color(red: 1, green: 0.89, blue: 0.14)
    static let muted = Color(white: 0.65)
    static let text = Color(white: 0.36)
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image.appSymbol( icon) }
                Text(title).tracking(2)
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Palette.blue, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SectionBand: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 6)
            .background(Palette.blue)
    }
}

struct EmptyMessage: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 14) {
            Image.appSymbol( icon).font(.system(size: 36, weight: .light)).foregroundStyle(Palette.blue)
            Text(title).font(.title3.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(40)
    }
}

#if os(Android)
@MainActor
final class FrenchSpeaker {
    var engine: AndroidSpeechEngine?
    func speak(_ text: String) {
        if engine == nil { engine = AndroidSpeechEngine() }
        engine?.speak(text)
    }
    func stop() { engine?.shutdown(); engine = nil }
}
#endif

extension View {
    @ViewBuilder
    func speechPlaybackAlert(_ speaker: FrenchSpeaker) -> some View {
        #if os(Android)
        self
        #else
        self.alert("无法播放语音", isPresented: Binding(
            get: { speaker.errorMessage != nil },
            set: { if !$0 { speaker.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { speaker.errorMessage = nil }
        } message: {
            Text(speaker.errorMessage ?? "")
        }
        #endif
    }
}

/// An original vector silhouette, drawn in code to avoid borrowing an app asset.
struct ParisSkyline: View {
    var body: some View {
        #if os(Android)
        Image("ParisSkyline", bundle: AppResources.bundle).resizable().accessibilityHidden(true)
        #else
        Canvas { context, size in
            let sx = size.width / 440
            let sy = size.height / 320
            context.scaleBy(x: sx, y: sy)
            let ink = Color(red: 0.59, green: 0.65, blue: 0.67).opacity(0.54)
            func line(_ points: [CGPoint], width: CGFloat = 1.5) {
                var p = Path(); p.addLines(points)
                context.stroke(p, with: .color(ink), lineWidth: width)
            }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
                context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(ink))
            }
            // Eiffel Tower: curved legs, first/second platforms, lattice and antenna.
            var tower = Path()
            tower.move(to: CGPoint(x: 88, y: 305))
            tower.addCurve(to: CGPoint(x: 143, y: 49), control1: CGPoint(x: 132, y: 244), control2: CGPoint(x: 141, y: 123))
            tower.addLine(to: CGPoint(x: 148, y: 49))
            tower.addCurve(to: CGPoint(x: 202, y: 305), control1: CGPoint(x: 151, y: 133), control2: CGPoint(x: 160, y: 245))
            tower.addLine(to: CGPoint(x: 181, y: 305))
            tower.addCurve(to: CGPoint(x: 109, y: 305), control1: CGPoint(x: 165, y: 270), control2: CGPoint(x: 130, y: 269))
            tower.closeSubpath()
            context.stroke(tower, with: .color(ink), lineWidth: 2)
            line([CGPoint(x: 145.5,y: 4), CGPoint(x: 145.5,y: 50)], width: 2)
            rect(138, 34, 15, 14); rect(136, 39, 19, 7)
            rect(126, 195, 39, 10); rect(110, 250, 71, 10)
            rect(105, 263, 80, 10)
            for i in 0..<24 {
                let y = CGFloat(53 + i * 8)
                let half: CGFloat = 2.5 + pow((y - 45) / 250, 2.3) * 41
                let next: CGFloat = 2.5 + pow((y + 8 - 45) / 250, 2.3) * 41
                line([CGPoint(x:145.5-half,y:y), CGPoint(x:145.5+half,y:y)])
                line([CGPoint(x:145.5-half,y:y), CGPoint(x:145.5+next,y:y+8)], width: 1)
                line([CGPoint(x:145.5+half,y:y), CGPoint(x:145.5-next,y:y+8)], width: 1)
            }
            for i in 0..<7 {
                let x = CGFloat(111 + i*11)
                line([CGPoint(x:x,y:250),CGPoint(x:x,y:263)],width: 1)
            }
            // Sacré-Cœur and a varied Paris roofline.
            rect(247, 280, 93, 40); rect(256, 258, 75, 40)
            var dome = Path()
            dome.move(to: CGPoint(x:277,y:259))
            dome.addCurve(to: CGPoint(x:308,y:259),control1:CGPoint(x:268,y:218),control2:CGPoint(x:315,y:218))
            dome.closeSubpath(); context.fill(dome,with:.color(ink))
            rect(289, 209, 6, 22)
            line([CGPoint(x:292,y:204),CGPoint(x:292,y:214)],width: 1)
            line([CGPoint(x:289,y:207),CGPoint(x:295,y:207)],width: 1)
            for x: CGFloat in [259,320] {
                context.fill(Path(ellipseIn:CGRect(x:x,y:246,width:11,height:22)),with:.color(ink))
                rect(x+4,238,3,13)
            }
            for x: CGFloat in [280,289,299] {
                let p = Path(roundedRect:CGRect(x:x,y:266,width:4,height:14),cornerRadius:2)
                context.blendMode = .destinationOut
                context.fill(p,with:.color(.black))
                context.blendMode = .normal
            }
            rect(0, 302, 440, 18)
            for i in 0..<42 {
                let x = CGFloat(i) * 11
                let h = CGFloat([13,18,11,22,16,19,12,15,25,17,10][i % 11])
                rect(x,302-h,12,h+3)
                var roof = Path()
                roof.move(to:CGPoint(x:x,y:302-h)); roof.addLine(to:CGPoint(x:x+6,y:298-h))
                roof.addLine(to:CGPoint(x:x+12,y:302-h)); roof.closeSubpath()
                context.fill(roof,with:.color(ink))
            }
        }
        .accessibilityHidden(true)
        #endif
    }
}

extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.13), radius: 3, x: 0, y: 1)
    }
}


extension Image {
    static func appSymbol(_ name: String) -> Image {
        #if os(Android)
        switch name {
        case "arrow.clockwise", "arrow.triangle.2.circlepath", "book", "circle", "clock", "dice",
             "doc.on.doc", "doc.text.magnifyingglass", "ellipsis.circle", "ellipsis.circle.fill",
             "eyeglasses", "headphones", "keyboard.chevron.compact.down", "list.number", "person.2",
             "shuffle", "slider.horizontal.3", "speaker.wave.2", "star", "switch.2", "xmark.circle.fill":
            return Image("android-" + name, bundle: AppResources.bundle).renderingMode(.template)
        default:
            return Image(systemName: name)
        }
        #else
        return Image(systemName: name)
        #endif
    }
}

struct AppLabel: View {
    let title: String
    let systemImage: String
    var body: some View {
        Label { Text(title) } icon: { Image.appSymbol(systemImage) }
    }
}


extension View {
    @ViewBuilder
    func appSelectableText(_ text: String) -> some View {
        #if os(Android)
        self.contextMenu {
            Button("复制") { UIPasteboard.general.string = text }
        }
        #else
        self.textSelection(.enabled)
        #endif
    }
}


enum PlatformLayout {
    static var isAndroid: Bool {
        #if os(Android)
        return true
        #else
        return false
        #endif
    }
    static var pinnedHeaders: PinnedScrollableViews {
        #if os(Android)
        return []
        #else
        return [.sectionHeaders]
        #endif
    }
}

extension View {
    @ViewBuilder
    func appContentShape() -> some View {
        #if os(Android)
        self
        #else
        self.contentShape(Rectangle())
        #endif
    }

    @ViewBuilder
    func appTopInset<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(Android)
        VStack(spacing: 0) { content(); self }
        #else
        self.safeAreaInset(edge: .top, spacing: 0, content: content)
        #endif
    }

    @ViewBuilder
    func appAccessibilityHint(_ hint: String, label: String) -> some View {
        #if os(Android)
        self.accessibilityLabel(Text(label + "，" + hint))
        #else
        self.accessibilityHint(hint)
        #endif
    }
}


extension View {
    @ViewBuilder
    func appVerbListCoordinateSpace() -> some View {
        #if os(Android)
        self
        #else
        self.coordinateSpace(name: "verbs")
        #endif
    }

    @ViewBuilder
    func appKeyboardToolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(Android)
        self
        #else
        self.toolbar { ToolbarItem(placement: .keyboard, content: content) }
        #endif
    }
}
