import AppKit
import SwiftUI
import QuadCastStudioCore

@main
@MainActor
struct QuadCastStudioApp: App {
    @StateObject private var controller = DeviceController()

    var body: some Scene {
        WindowGroup("QuadCast Studio") {
            MainWindow(controller: controller)
                .frame(minWidth: 820, minHeight: 660)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    controller.stopForQuit()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1050, height: 760)
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var saved: [SavedProfile] = []
    private let key = "QuadCastStudio.CustomProfiles.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let profiles = try? JSONDecoder().decode([SavedProfile].self, from: data) {
            saved = profiles
        }
    }

    func save(name: String, configuration: LightingConfiguration) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        saved.append(SavedProfile(name: String(cleaned.prefix(60)), configuration: configuration))
        persist()
    }

    func delete(id: UUID) {
        saved.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct BuiltInPreset: Identifiable {
    let name: String
    let configuration: LightingConfiguration
    var id: String { name }

    static let all: [BuiltInPreset] = [
        .init(name: "Studio Cyan", configuration: .studioCyan),
        .init(name: "On Air", configuration: .onAir),
        .init(name: "Calm Indigo", configuration: .indigo),
        .init(name: "Sunset Split", configuration: .sunset),
        .init(name: "Rainbow Wave", configuration: .rainbow),
        .init(name: "Lights Off", configuration: .lightsOff)
    ]
}

@MainActor
struct MainWindow: View {
    @ObservedObject var controller: DeviceController
    @StateObject private var profiles = ProfileStore()
    @State private var draft: LightingConfiguration = .studioCyan
    @State private var showingSave = false
    @State private var profileName = ""
    @State private var showingDiagnostics = false

    private let background = Color(hex: "0B0D10")
    private let panel = Color(hex: "171A1F")
    private let muted = Color(hex: "939BA8")
    private let cyan = Color(hex: "64E1FF")

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    HStack(alignment: .top, spacing: 20) {
                        leftPanel.frame(width: 280)
                        VStack(spacing: 20) {
                            visualizer
                            editor
                        }.frame(maxWidth: .infinity)
                    }
                    statusFooter
                }
                .padding(28)
            }
        }
        .onReceive(Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()) { _ in
            controller.refreshConnection()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            controller.refreshConnection()
        }
        .sheet(isPresented: $showingSave) { saveSheet }
        .sheet(isPresented: $showingDiagnostics) { diagnosticsSheet }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundStyle(cyan)
                    Text("QUADCAST STUDIO")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(2.5)
                }
                Text("Light your voice. Native control for HyperX QuadCast S.")
                    .foregroundStyle(muted)
                    .font(.system(size: 12))
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.state.label)
                        .font(.system(size: 12, weight: .semibold))
                    Text(controller.microphone?.identifier ?? "No compatible device")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(muted)
                }
                Button { controller.refreshConnection() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh read-only USB connection status")
            }
            .padding(11)
            .background(panel, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("LIGHTING PROFILES")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(muted)
                Spacer()
                Image(systemName: "square.stack").foregroundStyle(muted)
            }

            ForEach(BuiltInPreset.all) { item in
                profileButton(title: item.name, config: item.configuration)
            }

            Divider().overlay(.white.opacity(0.08))
            HStack {
                Text("MY PROFILES")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(muted)
                Spacer()
                Button { showingSave = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(cyan)
                }.buttonStyle(.plain).help("Save current configuration")
            }
            if profiles.saved.isEmpty {
                Text("Your custom profiles will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .padding(.vertical, 12)
            } else {
                ForEach(profiles.saved) { item in
                    HStack {
                        Button {
                            draft = item.configuration
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bookmark")
                                Text(item.name).lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) { profiles.delete(id: item.id) } label: {
                            Image(systemName: "trash").foregroundStyle(muted)
                        }.buttonStyle(.plain).help("Delete profile")
                    }.padding(8)
                }
            }
            Spacer(minLength: 10)
            Button { showingDiagnostics = true } label: {
                Label("Connection diagnostics", systemImage: "stethoscope")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderless)
            .foregroundStyle(muted)
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func profileButton(title: String, config: LightingConfiguration) -> some View {
        Button { draft = config } label: {
            HStack(spacing: 11) {
                Circle()
                    .fill(config.effect == .off ? Color.gray : Color(hex: config.upperHex))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                if draft == config { Image(systemName: "checkmark").foregroundStyle(cyan) }
            }
            .padding(11)
            .background(draft == config ? cyan.opacity(0.10) : Color.white.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var visualizer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("LIVE DESIGN PREVIEW", systemImage: "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(muted)
                Spacer()
                Text("REQUESTED · NOT READBACK")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(muted)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "10151C"))
                Circle()
                    .fill((draft.effect == .off ? .clear : Color(hex: draft.upperHex)).opacity(0.35))
                    .frame(width: 170, height: 170)
                    .blur(radius: 52)
                    .offset(y: -25)
                VStack(spacing: 0) {
                    Capsule()
                        .fill(LinearGradient(colors: draft.effect == .off ? [Color(hex: "30343B")] :
                            [Color(hex: draft.upperHex), Color(hex: draft.lowerHex)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 86, height: 167)
                        .overlay {
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 2)
                        }
                        .overlay {
                            VStack(spacing: 9) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Capsule().fill(.black.opacity(0.3)).frame(width: 55, height: 3)
                                }
                            }
                        }
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: "555C65"))
                        .frame(width: 16, height: 39)
                    Capsule().fill(Color(hex: "555C65")).frame(width: 90, height: 9)
                }
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            }
            .frame(height: 270)
            HStack {
                Label("Upper: #\(draft.upperHex)", systemImage: "circle.tophalf.filled")
                Spacer()
                Label("Lower: #\(draft.lowerHex)", systemImage: "circle.bottomhalf.filled")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(muted)
        }
        .padding(19)
        .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Lighting controls")
                .font(.system(size: 18, weight: .bold))
            HStack {
                Text("Effect")
                    .foregroundStyle(muted)
                Spacer()
                Picker("Effect", selection: $draft.effect) {
                    ForEach(LightingEffect.allCases) { effect in
                        Text(effect.rawValue).tag(effect)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            HStack(spacing: 18) {
                colorControl("Upper zone", color: $draft.upperHex)
                colorControl("Lower zone", color: $draft.lowerHex)
            }
            .disabled(draft.effect == .off || draft.effect == .wave || draft.effect == .cycle)
            VStack(spacing: 4) {
                HStack {
                    Text("Brightness").foregroundStyle(muted)
                    Spacer()
                    Text("\(draft.brightness)%").monospacedDigit()
                }
                Slider(value: Binding(get: { Double(draft.brightness) },
                                      set: { draft.brightness = Int($0.rounded()) }), in: 0...100, step: 1)
                    .tint(cyan)
            }.disabled(draft.effect == .off)
            if draft.effect != .solid && draft.effect != .off {
                VStack(spacing: 4) {
                    HStack {
                        Text("Effect speed").foregroundStyle(muted)
                        Spacer()
                        Text("\(draft.speed)%").monospacedDigit()
                    }
                    Slider(value: Binding(get: { Double(draft.speed) },
                                          set: { draft.speed = Int($0.rounded()) }), in: 1...100, step: 1)
                        .tint(cyan)
                }
            }
            if draft.effect == .cycle || draft.effect == .wave {
                Text("Cycle and wave use the controller's built-in rainbow palette.")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            Divider().overlay(.white.opacity(0.08))
            HStack {
                Button { controller.apply(draft) } label: {
                    HStack { Image(systemName: "bolt.fill"); Text("Apply lighting") }
                        .frame(minWidth: 155)
                }
                .buttonStyle(.borderedProminent)
                .tint(cyan)
                .foregroundStyle(.black)
                .disabled(!controller.canApply)
                Button("Test cyan") { draft = .studioCyan; controller.apply(.studioCyan) }
                    .disabled(!controller.canApply)
                Spacer()
                Button { showingSave = true } label: {
                    Label("Save profile", systemImage: "square.and.arrow.down")
                }
            }
            if controller.state == .active {
                HStack(spacing: 10) {
                    Text("Did the microphone lighting actually change?")
                        .font(.system(size: 12))
                    Button("Yes") { controller.confirmHardwareChanged() }
                    Button("No") { controller.reportNoChange() }
                }
                .padding(10)
                .background(cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .font(.system(size: 12))
        .padding(19)
        .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func colorControl(_ title: String, color: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).foregroundStyle(muted).font(.system(size: 12))
            HStack(spacing: 7) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: color.wrappedValue) },
                    set: { color.wrappedValue = $0.toHex() }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 38)
                TextField("RRGGBB", text: color)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: color.wrappedValue) { newValue in
                        if newValue.count > 7 { color.wrappedValue = String(newValue.prefix(7)) }
                    }
            }
        }.frame(maxWidth: .infinity)
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(statusColor)
                Text(controller.state.label).fontWeight(.semibold)
            }
            if let message = controller.lastError {
                Text(message).foregroundStyle(Color(hex: "FFBC92"))
                    .textSelection(.enabled)
            } else if controller.state == .disconnected {
                Text("Connect your original QuadCast S directly to the Mac using a USB data cable.")
                    .foregroundStyle(muted)
            } else if controller.state == .missingBackend {
                Text("Install the existing controller: brew install quadcastrgb")
                    .foregroundStyle(muted)
            } else {
                Text("Uses your local Homebrew QuadcastRGB controller. No cloud connection, firmware writes, or audio recording.")
                    .foregroundStyle(muted)
            }
        }
        .font(.system(size: 12))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch controller.state {
        case .ready, .active, .verified: return Color(hex: "A5D62E")
        case .disconnected, .missingBackend: return muted
        case .applying: return cyan
        case .error: return Color(hex: "FF9B73")
        }
    }

    private var saveSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save lighting profile").font(.title2.weight(.bold))
            TextField("Profile name", text: $profileName)
            HStack {
                Spacer()
                Button("Cancel") { showingSave = false; profileName = "" }
                Button("Save") {
                    profiles.save(name: profileName, configuration: draft)
                    profileName = ""
                    showingSave = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private var diagnosticsSheet: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Connection diagnostics").font(.title2.weight(.bold))
            ScrollView {
                Text(controller.diagnostics)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 260)
            HStack {
                Button("Copy diagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(controller.diagnostics, forType: .string)
                }
                Spacer()
                Button("Close") { showingDiagnostics = false }
            }
        }
        .padding(24)
        .frame(width: 590)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0x64E1FF
        self.init(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
    }

    func toHex() -> String {
        let rgb = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.white
        return String(format: "%02X%02X%02X",
                      Int((rgb.redComponent * 255).rounded()),
                      Int((rgb.greenComponent * 255).rounded()),
                      Int((rgb.blueComponent * 255).rounded()))
    }
}
