import AppKit
import SwiftUI
import ServiceManagement
import QuadCastStudioCore

@MainActor
final class StudioSession: ObservableObject {
    @Published var draft: LightingConfiguration = .studioCyan
    var selectedName: String { BuiltInPreset.all.first(where: { $0.configuration == draft })?.name ?? "Custom draft" }
    @Published var message: String?
    func select(_ name: String, _ configuration: LightingConfiguration) {
        draft = configuration
    }
    func perform(_ work: () throws -> Void) {
        do { try work() } catch { message = error.localizedDescription }
    }
}

@MainActor
final class LoginService: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var detail = "Launch at login is off."
    init() { refresh() }
    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        switch status {
        case .enabled: detail = "Launch at login is enabled."
        case .requiresApproval: detail = "Approve QuadCast Studio in System Settings → General → Login Items."
        case .notFound: detail = "Build and launch the .app bundle to configure login."
        default: detail = "Launch at login is off."
        }
    }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch { refresh(); detail = "Could not update launch at login: \(error.localizedDescription)" }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: DeviceController?
    private var terminationPending = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationPending else { return .terminateLater }
        guard let controller else { return .terminateNow }
        terminationPending = true
        Task { @MainActor in
            let stopped = await controller.shutdown()
            self.terminationPending = false
            if !stopped {
                let alert = NSAlert()
                alert.messageText = "Controller is still stopping"
                alert.informativeText = "QuadCast Studio will remain open to keep ownership of its controller process. Use Stop controller and try quitting again."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            sender.reply(toApplicationShouldTerminate: stopped)
        }
        return .terminateLater
    }
}

struct MenuBarController: View {
    @ObservedObject var controller: DeviceController
    @ObservedObject var profiles: ProfileStore
    @ObservedObject var session: StudioSession
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(controller.state.label, systemImage: controller.microphone == nil ? "mic.slash" : "mic")
                .font(.headline).accessibilityAddTraits(.updatesFrequently)
            Text(controller.microphone?.identifier ?? "No original QuadCast S detected").font(.caption).foregroundStyle(.secondary)
            Picker("Preview profile", selection: Binding(get: { session.selectedName }, set: { name in
                if let preset = BuiltInPreset.all.first(where: { $0.name == name }) { session.select(name, preset.configuration) }
            })) {
                Text("Custom draft").tag("Custom draft")
                ForEach(BuiltInPreset.all) { Text($0.name).tag($0.name) }
            }
            if !profiles.saved.isEmpty {
                Menu("My profiles") {
                    ForEach(profiles.ordered) { profile in
                        Button { session.select(profile.name, profile.configuration) } label: { Label(profile.name, systemImage: profile.isFavorite ? "star.fill" : "bookmark") }
                    }
                }
            }
            HStack { Text("Preview brightness"); Spacer(); Text("\(session.draft.brightness)%").monospacedDigit() }
            Slider(value: Binding(get: { Double(session.draft.brightness) }, set: { session.draft.brightness = Int($0.rounded()) }), in: 0...100, step: 1)
                .accessibilityLabel("Preview brightness").accessibilityValue("\(session.draft.brightness) percent")
            Text("Selection edits the shared preview. Apply sends a command; no LED state is read back.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Apply lighting") { controller.apply(session.draft) }.disabled(!controller.canApply || (try? session.draft.arguments()) == nil)
                Button("RGB off") { session.select("Lights Off", .lightsOff); controller.apply(.lightsOff) }.disabled(!controller.canApply)
            }
            Button("Stop controller") { controller.stopController() }.disabled(controller.busy || controller.ownedPID == nil)
            if let error = controller.lastError { Text(error).font(.caption).foregroundStyle(.orange) }
            Divider()
            HStack {
                Button("Open Studio") { openWindow(id: "studio"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }.padding(18).frame(width: 340)
    }
}
