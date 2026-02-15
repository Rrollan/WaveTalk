import SwiftUI
import AVFoundation
import Cocoa

// MARK: - Core Logic
class WaveTalkState: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: CGFloat = 0.0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    
    func start() {
        if isRecording { return }
        isRecording = true
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let url = URL(fileURLWithPath: "/tmp/wavetalk_input.m4a")
        try? FileManager.default.removeItem(at: url)
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.isMeteringEnabled = true
            recorder?.record()
            timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
                self.recorder?.updateMeters()
                let power = self.recorder?.averagePower(forChannel: 0) ?? -60
                // Higher reactivity for the wave
                let level = CGFloat(max(0, min(1.0, (power + 45) / 35)))
                DispatchQueue.main.async {
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.6)) {
                        self.audioLevel = level
                    }
                }
            }
        } catch { print(error) }
    }
    
    func stop() {
        if !isRecording { return }
        isRecording = false
        audioLevel = 0
        timer?.invalidate()
        recorder?.stop()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["/Applications/WaveTalk/Scripts/process.sh"]
        try? task.run()
    }
}

// MARK: - UI Components
struct LiquidWaveShape: Shape {
    var level: CGFloat // 0 to 1
    var phase: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(level, phase) }
        set {
            level = newValue.first
            phase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Base progress (0.1 so it's always visible at bottom)
        let progress = 1.0 - (level * 0.8 + 0.1)
        let midHeight = progress * height
        let waveHeight: CGFloat = 5.0
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 + phase)
            let y = midHeight + sine * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct MainView: View {
    @ObservedObject var state: WaveTalkState
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Glass Background
            VisualEffectView()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            // Animated Liquid Wave
            LiquidWaveShape(level: state.audioLevel, phase: phase)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.green.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        phase = .pi * 2
                    }
                }
            
            // Mic Icon
            Image(systemName: "mic.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .opacity(state.isRecording ? 1.0 : 0.2)
                .blendMode(.overlay)
        }
        .frame(width: 80, height: 80)
        .scaleEffect(state.isRecording ? 1.0 : 0.8)
        .opacity(state.isRecording ? 1.0 : 0.0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var state = WaveTalkState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 100) / 2
            let y: CGFloat = 120
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: MainView(state: state))
        
        setupHotkeys()
        window.orderOut(nil)
    }
    
    func setupHotkeys() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd + B (keyCode 11)
            if event.modifierFlags.contains(.command) && event.keyCode == 11 {
                DispatchQueue.main.async {
                    self?.state.start()
                    self?.window.makeKeyAndOrderFront(nil)
                }
            }
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.keyCode == 11 {
                DispatchQueue.main.async {
                    self?.state.stop()
                    self?.window.orderOut(nil)
                }
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
