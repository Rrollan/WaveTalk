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
                // Normalize level for the "liquid" height
                let level = CGFloat(max(0, min(1.0, (power + 50) / 45)))
                DispatchQueue.main.async {
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.7)) {
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
struct SquircleShape: Shape {
    var curvature: Double = 4
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a = rect.width / 2
        let b = rect.height / 2
        let centerX = rect.midX
        let centerY = rect.midY
        path.move(to: CGPoint(x: centerX, y: centerY - b))
        for angle in stride(from: 0.0, through: 360.0, by: 1.0) {
            let theta = angle * .pi / 180
            let cosTheta = cos(theta)
            let sinTheta = sin(theta)
            let r = pow(pow(abs(cosTheta), curvature) + pow(abs(sinTheta), curvature), -1.0 / curvature)
            path.addLine(to: CGPoint(x: centerX + r * a * cosTheta, y: centerY + r * b * sinTheta))
        }
        path.closeSubpath()
        return path
    }
}

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
        let progress = 1.0 - level
        let midHeight = progress * height
        let waveHeight: CGFloat = level > 0 ? 5.0 : 0.0
        
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
            VisualEffectView()
                .clipShape(SquircleShape())
                .overlay(SquircleShape().stroke(.white.opacity(0.15), lineWidth: 0.5))
            
            LiquidWaveShape(level: state.audioLevel, phase: phase)
                .fill(LinearGradient(colors: [Color.green.opacity(0.5), Color.green], startPoint: .top, endPoint: .bottom))
                .mask(SquircleShape())
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        phase = .pi * 2
                    }
                }
            
            Image(systemName: "mic.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .opacity(state.isRecording ? 1.0 : 0.3)
                .shadow(radius: 5)
        }
        .frame(width: 80, height: 80)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var state = WaveTalkState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 120, height: 120), styleMask: [.borderless], backing: .buffered, defer: false)
        
        // Position at bottom center
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 120) / 2
            let y: CGFloat = 80 // Bottom offset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: MainView(state: state))
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
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
        window.orderOut(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
