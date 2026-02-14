import SwiftUI
import AVFoundation
import Cocoa

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
                let level = CGFloat(max(0, min(1.0, (power + 50) / 45)))
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

struct WaveFiller: View {
    let level: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Wave/Liquid fill effect
                Rectangle()
                    .fill(LinearGradient(colors: [Color.green.opacity(0.6), Color.green], startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * level)
                    .offset(y: geo.size.height * (1 - level) / 2)
                    .animation(.interpolatingSpring(stiffness: 100, damping: 10), value: level)
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var state: WaveTalkState
    var body: some View {
        ZStack {
            VisualEffectView()
                .clipShape(SquircleShape())
                .overlay(SquircleShape().stroke(.white.opacity(0.2), lineWidth: 0.5))
            
            WaveFiller(level: state.audioLevel)
                .mask(SquircleShape())
            
            Image(systemName: "mic.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(state.isRecording ? .white : .white.opacity(0.3))
                .shadow(radius: 5)
        }
        .frame(width: 80, height: 80)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var state = WaveTalkState()
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.center()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: MainView(state: state))
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 11 {
                DispatchQueue.main.async { self?.state.start(); self?.window.makeKeyAndOrderFront(nil) }
            }
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.keyCode == 11 { DispatchQueue.main.async { self?.state.stop(); self?.window.orderOut(nil) } }
        }
        window.orderOut(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
