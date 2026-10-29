import AppKit
import SwiftUI
import UniformTypeIdentifiers
import QuadCastStudioCore

@main
@MainActor
struct QuadCastStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = DeviceController()
    @StateObject private var profiles = ProfileStore()
    @StateObject private var session = StudioSession()
    @StateObject private var login = LoginService()
    var body: some Scene {
        WindowGroup("QuadCast Studio", id: "studio") {
            MainWindow(controller: controller, profiles: profiles, session: session, login: login)
                .frame(minWidth: 820, minHeight: 660)
                .preferredColorScheme(.dark)
                .onAppear { appDelegate.controller = controller }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1050, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Apply lighting") { controller.apply(session.draft) }
                    .keyboardShortcut(.return, modifiers: .command).disabled(!controller.canApply)
                Button("Stop controller") { controller.stopController() }
                    .keyboardShortcut(".", modifiers: .command).disabled(controller.busy)
            }
        }
        MenuBarExtra("QuadCast Studio", systemImage: controller.microphone == nil ? "mic.slash" : "mic") {
            MenuBarController(controller: controller, profiles: profiles, session: session)
                .onAppear { appDelegate.controller = controller }
        }.menuBarExtraStyle(.window)
    }
}

struct BuiltInPreset: Identifiable {
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
    @ObservedObject var profiles: ProfileStore
    @ObservedObject var session: StudioSession
    @ObservedObject var login: LoginService
    @State private var showingSave = false
    @State private var profileName = ""
    @State private var showingDiagnostics = false
    @State private var renamingID: UUID?
    @State private var deleting: SavedProfile?
    @State private var showingRestoreConsent = false

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
        .sheet(isPresented: $showingSave) { saveSheet }
        .sheet(isPresented: $showingDiagnostics) { diagnosticsSheet }
        .alert("Profile operation failed", isPresented: Binding(get: { session.message != nil }, set: { if !$0 { session.message = nil } })) {
            Button("OK") { session.message = nil }
        } message: { Text(session.message ?? "") }
        .confirmationDialog("Delete profile?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let profile = deleting { session.perform { try profiles.delete(id: profile.id) } }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("Delete \(deleting?.name ?? "this profile") from the local library?") }
        .alert("Restore lighting after reconnect?", isPresented: $showingRestoreConsent) {
            Button("Enable restore") { controller.restoreAfterReconnect = true }
            Button("Cancel", role: .cancel) {}
        } message: { Text("After USB reconnect or wake, QuadCast Studio may automatically apply the last successfully started lighting configuration. Launching the app alone does not apply lighting. You can turn this off at any time.") }
        .onAppear { if let error = profiles.loadError { session.message = error } }
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
                .help("Refresh read-only USB connection status").accessibilityLabel("Check USB connection")
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
                Button { renamingID = nil; profileName = ""; showingSave = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(cyan)
                }.buttonStyle(.plain).help("Save current configuration").accessibilityLabel("Save current configuration")
            }
            if profiles.saved.isEmpty {
                Text("Your custom profiles will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .padding(.vertical, 12)
            } else {
                ForEach(profiles.ordered) { item in
                    HStack {
                        Button {
                            session.draft = item.configuration
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.isFavorite ? "star.fill" : "bookmark")
                                Text(item.name).lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Button("Rename…") { renamingID = item.id; profileName = item.name; showingSave = true }
                            Button("Duplicate") { session.perform { try profiles.duplicate(id: item.id) } }
                            Button(item.isFavorite ? "Remove favorite" : "Favorite") { session.perform { try profiles.toggleFavorite(id: item.id) } }
                            Divider()
                            Button("Delete…", role: .destructive) { deleting = item }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).frame(width: 24)
                        .accessibilityLabel("Actions for \(item.name)")
                    }.padding(8)
                }
            }
            HStack {
                Button("Import JSON…") { importProfiles() }
                Button("Export JSON…") { exportProfiles() }.disabled(profiles.saved.isEmpty)
            }.font(.caption)
            if let error = profiles.loadError { Text(error).font(.caption).foregroundStyle(.orange) }
            Divider()
            Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
            Text(login.detail).font(.caption).foregroundStyle(muted)
            Button("Refresh login status") { login.refresh() }.font(.caption)
            Toggle("Restore after reconnect / wake", isOn: Binding(get: { controller.restoreAfterReconnect }, set: { enabled in
                if enabled { showingRestoreConsent = true } else { controller.restoreAfterReconnect = false }
            }))
            Text("Off by default. Restore uses the last applied configuration, not an uncommitted preview.").font(.caption).foregroundStyle(muted)
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
        Button { session.select(title, config) } label: {
            HStack(spacing: 11) {
                Circle()
                    .fill(config.effect == .off ? Color.gray : Color(hex: config.upperHex))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                if session.draft == config { Image(systemName: "checkmark").foregroundStyle(cyan) }
            }
            .padding(11)
            .background(session.draft == config ? cyan.opacity(0.10) : Color.white.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var visualizer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("DESIGN PREVIEW", systemImage: "eye")
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
                    .fill((session.draft.effect == .off ? .clear : Color(hex: session.draft.upperHex)).opacity(0.35))
                    .frame(width: 170, height: 170)
                    .blur(radius: 52)
                    .offset(y: -25)
                VStack(spacing: 0) {
                    Capsule()
                        .fill(LinearGradient(colors: session.draft.effect == .off ? [Color(hex: "30343B")] :
                            [Color(hex: session.draft.upperHex), Color(hex: session.draft.lowerHex)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 86, height: 167)
                        .opacity(session.draft.effect == .off ? 1 : Double(session.draft.brightness) / 100)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Illustrative lighting preview, \(session.draft.effect.rawValue), upper \(session.draft.upperHex), lower \(session.draft.lowerHex), brightness \(session.draft.brightness) percent. Not LED state readback.")
            HStack {
                Label("Upper: #\(session.draft.upperHex)", systemImage: "circle.tophalf.filled")
                Spacer()
                Label("Lower: #\(session.draft.lowerHex)", systemImage: "circle.bottomhalf.filled")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(muted)
        }
        .padding(19)
        .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Preview changes stay local until you choose Apply lighting.")
                .font(.callout).foregroundStyle(muted)
            Text("Lighting controls")
                .font(.system(size: 18, weight: .bold))
            HStack {
                Text("Effect")
                    .foregroundStyle(muted)
                Spacer()
                Picker("Effect", selection: $session.draft.effect) {
                    ForEach(LightingEffect.allCases) { effect in
                        Text(effect.rawValue).tag(effect)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            HStack(spacing: 18) {
                colorControl("Upper zone", color: $session.draft.upperHex)
                colorControl("Lower zone", color: $session.draft.lowerHex)
            }
            .disabled(session.draft.effect == .off || session.draft.effect == .wave || session.draft.effect == .cycle)
            VStack(spacing: 4) {
                HStack {
                    Text("Brightness").foregroundStyle(muted)
                    Spacer()
                    Text("\(session.draft.brightness)%").monospacedDigit()
                }
                Slider(value: Binding(get: { Double(session.draft.brightness) },
                                      set: { session.draft.brightness = Int($0.rounded()) }), in: 0...100, step: 1)
                    .tint(cyan).accessibilityLabel("Preview brightness").accessibilityValue("\(session.draft.brightness) percent")
            }.disabled(session.draft.effect == .off)
            if session.draft.effect != .solid && session.draft.effect != .off {
                VStack(spacing: 4) {
                    HStack {
                        Text("Effect speed").foregroundStyle(muted)
                        Spacer()
                        Text("\(session.draft.speed)%").monospacedDigit()
                    }
                    Slider(value: Binding(get: { Double(session.draft.speed) },
                                          set: { session.draft.speed = Int($0.rounded()) }), in: 1...100, step: 1)
                        .tint(cyan).accessibilityLabel("Effect speed").accessibilityValue("\(session.draft.speed) percent")
                }
            }
            if session.draft.effect == .cycle || session.draft.effect == .wave {
                Text("Cycle and wave use the controller's built-in rainbow palette.")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            Divider().overlay(.white.opacity(0.08))
            HStack {
                Button { controller.apply(session.draft) } label: {
                    HStack { Image(systemName: "bolt.fill"); Text("Apply lighting") }
                        .frame(minWidth: 155)
                }
                .buttonStyle(.borderedProminent)
                .tint(cyan)
                .foregroundStyle(.black)
                .disabled(!controller.canApply || (try? session.draft.arguments()) == nil)
                Button("Test cyan") { session.draft = .studioCyan; controller.apply(.studioCyan) }
                    .disabled(!controller.canApply)
                Button("RGB off") { session.select("Lights Off", .lightsOff); controller.apply(.lightsOff) }.disabled(!controller.canApply)
            }
            if (try? session.draft.arguments()) == nil {
                Text("Check both RGB values, brightness and effect speed before applying.").foregroundStyle(.orange)
            }
            HStack {
                Button("Stop controller") { controller.stopController() }
                    .disabled(controller.busy || controller.ownedPID == nil)
                Spacer()
                Button { renamingID = nil; profileName = ""; showingSave = true } label: {
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
                .frame(width: 38).accessibilityLabel("\(title) color")
                TextField("RRGGBB", text: color)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .accessibilityLabel("\(title) hexadecimal color")
            }
        }.frame(maxWidth: .infinity)
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(statusColor)
                Text(controller.state.label).fontWeight(.semibold).accessibilityAddTraits(.updatesFrequently)
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
            Text(renamingID == nil ? "Save lighting profile" : "Rename lighting profile").font(.title2.weight(.bold))
            TextField("Profile name", text: $profileName)
            HStack {
                Spacer()
                Button("Cancel") { showingSave = false; profileName = ""; renamingID = nil }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        if let id = renamingID { try profiles.rename(id: id, to: profileName) }
                        else { try profiles.save(name: profileName, configuration: session.draft) }
                        profileName = ""; renamingID = nil; showingSave = false
                    } catch { session.message = error.localizedDescription; showingSave = false }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled((try? ProfileDocument.checkedName(profileName)) == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func importProfiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            session.perform {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: ProfileDocument.maximumBytes + 1) ?? Data()
                try profiles.importJSON(data)
            }
        }
    }
    private func exportProfiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "QuadCast-Profiles.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            session.perform { try profiles.exportJSON().write(to: url, options: .atomic) }
        }
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
                Button("Close") { showingDiagnostics = false }.keyboardShortcut(.cancelAction)
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
