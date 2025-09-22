import Foundation
import ApplicationServices  // for CGEvent

final class HumanTyperEngine: ObservableObject {
    @Published var isTyping = false
    @Published var countdown = 0

    private var shouldStop = false
    private var worker: Thread?
    private var countdownTimer: Timer?

    func start(
        text: String,
        wpm: Double,
        jitter: Double,
        pauseSpaces: Bool, spaceRange: ClosedRange<Double> = 0.05...0.15,
        pausePunct: Bool, punctRange: ClosedRange<Double> = 0.28...0.55,
        pauseParagraphs: Bool, paragraphRange: ClosedRange<Double> = 0.35...0.7,
        countdownSeconds: Int = 0
    ) {
        guard !text.isEmpty else { return }
        if isTyping { return }

        shouldStop = false
        countdownTimer?.invalidate()
        countdownTimer = nil

        if countdownSeconds > 0 {
            // Show countdown UI, but don't mark as typing yet
            DispatchQueue.main.async { self.countdown = countdownSeconds }
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self = self else { t.invalidate(); return }
                if self.shouldStop {
                    t.invalidate()
                    DispatchQueue.main.async { self.countdown = 0 }
                    return
                }
                if self.countdown <= 1 {
                    t.invalidate()
                    DispatchQueue.main.async {
                        self.countdown = 0
                        self.isTyping = true
                    }
                    self.launchTypingThread(
                        text: text, wpm: wpm, jitter: jitter,
                        pauseSpaces: pauseSpaces, spaceRange: spaceRange,
                        pausePunct: pausePunct, punctRange: punctRange,
                        pauseParagraphs: pauseParagraphs, paragraphRange: paragraphRange
                    )
                } else {
                    DispatchQueue.main.async { self.countdown -= 1 }
                }
            }
            RunLoop.main.add(countdownTimer!, forMode: .common)
        } else {
            // No countdown
            DispatchQueue.main.async { self.isTyping = true }
            launchTypingThread(
                text: text, wpm: wpm, jitter: jitter,
                pauseSpaces: pauseSpaces, spaceRange: spaceRange,
                pausePunct: pausePunct, punctRange: punctRange,
                pauseParagraphs: pauseParagraphs, paragraphRange: paragraphRange
            )
        }
    }

    func startWithCountdown(
        text: String,
        wpm: Double,
        jitter: Double,
        pauseSpaces: Bool, spaceRange: ClosedRange<Double> = 0.05...0.15,
        pausePunct: Bool, punctRange: ClosedRange<Double> = 0.28...0.55,
        pauseParagraphs: Bool, paragraphRange: ClosedRange<Double> = 0.35...0.7,
        seconds: Int = 5
    ) {
        start(
            text: text,
            wpm: wpm,
            jitter: jitter,
            pauseSpaces: pauseSpaces, spaceRange: spaceRange,
            pausePunct: pausePunct, punctRange: punctRange,
            pauseParagraphs: pauseParagraphs, paragraphRange: paragraphRange,
            countdownSeconds: seconds
        )
    }

    func stop() {
        shouldStop = true
        countdownTimer?.invalidate()
        countdownTimer = nil
        DispatchQueue.main.async {
            self.countdown = 0
            self.isTyping = false
        }
    }

    private func launchTypingThread(
        text: String,
        wpm: Double,
        jitter: Double,
        pauseSpaces: Bool, spaceRange: ClosedRange<Double>,
        pausePunct: Bool, punctRange: ClosedRange<Double>,
        pauseParagraphs: Bool, paragraphRange: ClosedRange<Double>
    ) {
        worker = Thread { [weak self] in
            self?.type(
                text: text, wpm: wpm, jitter: jitter,
                pauseSpaces: pauseSpaces, spaceRange: spaceRange,
                pausePunct: pausePunct, punctRange: punctRange,
                pauseParagraphs: pauseParagraphs, paragraphRange: paragraphRange
            )
        }
        worker?.start()
    }

    private func secPerChar(wpm: Double) -> Double {
        // ~5 chars per word; clamp to avoid divide-by-zero and silly values
        let safeWPM = max(5.0, min(300.0, wpm))
        return 60.0 / (safeWPM * 5.0)
    }

    private func type(
        text: String,
        wpm: Double,
        jitter: Double,
        pauseSpaces: Bool, spaceRange: ClosedRange<Double>,
        pausePunct: Bool, punctRange: ClosedRange<Double>,
        pauseParagraphs: Bool, paragraphRange: ClosedRange<Double>
    ) {
        let base = secPerChar(wpm: wpm)
        let j = max(0.0, min(0.8, jitter))

        for ch in text {
            if shouldStop { break }

            // Post key
            let scalars = String(ch).utf16
            guard
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                let up   = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            else { continue }

            down.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: Array(scalars))
            up.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: Array(scalars))
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            // Delay with jitter
            var delay = base * (1.0 + Double.random(in: -j...j))

            // Extra pauses
            if pauseSpaces && ch == " " {
                delay += Double.random(in: spaceRange)
            }
            if pausePunct {
                if ".!?".contains(ch) {
                    delay += Double.random(in: punctRange)
                } else if ",;:".contains(ch) {
                    // smaller pause for commas/semicolons; tweak as you like
                    delay += Double.random(in: 0.12...0.26)
                }
            }
            if ch == "\n" {
                if pauseParagraphs {
                    delay += Double.random(in: paragraphRange)
                } else {
                    delay += Double.random(in: 0.18...0.35)
                }
            }

            Thread.sleep(forTimeInterval: max(0.001, delay))
        }

        DispatchQueue.main.async {
            self.isTyping = false
        }
    }
}
