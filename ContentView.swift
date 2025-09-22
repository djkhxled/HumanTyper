import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: HumanTyperEngine

    @State private var inputText: String = "Typing like a human… \nClick Start, then switch to your doc and click where you want the text."
    @State private var wpm: Double = 55
    @State private var jitter: Double = 0.40
    @State private var pauseSpaces: Bool = true
    @State private var pausePunct: Bool = true
    @State private var pauseParagraphs: Bool = true
    @State private var spaceRange: ClosedRange<Double> = 0.05...0.15
    @State private var punctRange: ClosedRange<Double> = 0.28...0.55
    @State private var paragraphRange: ClosedRange<Double> = 0.35...0.7

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red:0.06, green:0.06, blue:0.10),
                        Color(red:0.02, green:0.02, blue:0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Animated blobs sized to window
                FloatingBlob(color: .purple, size: geo.size)
                FloatingBlob(color: .pink,   size: geo.size)
                FloatingBlob(color: .blue,   size: geo.size)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(spacing: 14) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: min(56, geo.size.width * 0.1), height: min(56, geo.size.width * 0.1))
                                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("HUMAN TYPER")
                                    .font(.system(size: max(22, min(28, geo.size.width * 0.04)), weight: .heavy, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white, .white.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                    )
                                Text("created by perk")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)

                                Text(statusText)
                                    .foregroundColor(.secondary)
                                    .font(.callout)
                            }
                            Spacer()
                        }

                        // Controls
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Speed & Randomness").font(.headline)

                                HStack(alignment: .top) {
                                    // WPM
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("WPM")
                                        HStack {
                                            Slider(value: $wpm, in: 20...160)
                                            Text("\(Int(wpm))")
                                                .frame(width: 44, alignment: .trailing)
                                        }
                                        Text("≈ ms/char: \(Int((60.0/(max(5.0,wpm)*5.0))*1000))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Divider().frame(height: 66)

                                    // Jitter
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Human Randomness")
                                        HStack {
                                            Slider(value: $jitter, in: 0...0.8)
                                            Text(String(format: "±%.2f", jitter))
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                        Text("Varies timing to feel natural")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer(minLength: 8)
                                }

                                // Randomness toggles and sliders
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle("Pause on spaces", isOn: $pauseSpaces)
                                    if pauseSpaces {
                                        PauseRangeControls(
                                            title: "Space pause range:",
                                            range: $spaceRange,
                                            min: 0.01, max: 0.50
                                        )
                                    }

                                    Toggle("Pause on punctuation", isOn: $pausePunct)
                                    if pausePunct {
                                        PauseRangeControls(
                                            title: "Punctuation pause range:",
                                            range: $punctRange,
                                            min: 0.01, max: 1.00
                                        )
                                    }

                                    Toggle("Pause on paragraphs", isOn: $pauseParagraphs)
                                    if pauseParagraphs {
                                        PauseRangeControls(
                                            title: "Paragraph pause range:",
                                            range: $paragraphRange,
                                            min: 0.05, max: 2.00
                                        )
                                    }
                                }
                            }
                        }

                        // Text input
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Text to type").font(.headline)
                                TextEditor(text: $inputText)
                                    .font(.system(.body, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 220, maxHeight: max(220, geo.size.height * 0.35))
                                    .padding(8)
                                    .background(
                                        Color.white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                        }

                        // Actions
                        HStack {
                            Button {
                                engine.startWithCountdown(
                                    text: inputText,
                                    wpm: wpm,
                                    jitter: jitter,
                                    pauseSpaces: pauseSpaces, spaceRange: spaceRange,
                                    pausePunct: pausePunct, punctRange: punctRange,
                                    pauseParagraphs: pauseParagraphs, paragraphRange: paragraphRange,
                                    seconds: 5
                                )
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .buttonStyle(NeonButton(colors: [.pink, .purple]))
                            .disabled(engine.isTyping)

                            Button { engine.stop() } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(NeonButton(colors: [.gray, .black.opacity(0.6)]))
                            .keyboardShortcut(.escape, modifiers: [])

                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .font(.system(.body, design: .rounded))
                    .onAppear {
                        // Proactively prompt for Accessibility once
                        _ = AXIsProcessTrusted() // noop if already trusted
                    }
                }
            }
        }
    }

    private var statusText: String {
        if engine.countdown > 0 { return "Starting in \(engine.countdown)s…" }
        if engine.isTyping { return "Typing… (Esc to stop)" }
        return "Paste text · Set WPM · Start"
    }
}

// MARK: - Compact range controls used under each toggle
struct PauseRangeControls: View {
    let title: String
    @Binding var range: ClosedRange<Double>
    let min: Double
    let max: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f–%.2f s", range.lowerBound, range.upperBound))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Min")
                Slider(
                    value: Binding(
                        get: { range.lowerBound },
                        set: { newValue in range = newValue...Swift.max(newValue, range.upperBound) }
                    ),
                    in: min...range.upperBound
                )
                Text(String(format: "%.2f", range.lowerBound)).frame(width: 44, alignment: .trailing)
            }
            HStack {
                Text("Max")
                Slider(
                    value: Binding(
                        get: { range.upperBound },
                        set: { newValue in range = Swift.min(range.lowerBound, newValue)...newValue }
                    ),
                    in: range.lowerBound...max
                )
                Text(String(format: "%.2f", range.upperBound)).frame(width: 44, alignment: .trailing)
            }
        }
    }
}

// MARK: - UI helpers
struct GlassCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.22), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

struct NeonButton: ButtonStyle {
    var colors: [Color] = [.pink, .purple]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .foregroundStyle(.white)
            .shadow(color: colors.last!.opacity(0.55), radius: configuration.isPressed ? 4 : 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct FloatingBlob: View {
    let color: Color
    var size: CGSize
    @State private var move = false

    var body: some View {
        // Blob scales with min(windowWidth, windowHeight)
        let d = max(180.0, min(Double(min(size.width, size.height)) * 0.45, 520.0))
        let xOffset = move ? size.width * 0.32 : -size.width * 0.28
        let yOffset = move ? -size.height * 0.22 : size.height * 0.26

        return Circle()
            .fill(color)
            .blur(radius: 70)
            .frame(width: d, height: d)
            .opacity(0.18)
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    move.toggle()
                }
            }
    }
}
