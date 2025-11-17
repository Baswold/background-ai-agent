import SwiftUI

struct MenuBarView: View {
    weak var delegate: AppDelegate?
    @State private var isEnabled: Bool = true
    @State private var recentActivities: [Activity] = []
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Liquid glass background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with liquid glass effect
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10)

                        Spacer()

                        // On/Off Toggle
                        Toggle("", isOn: $isEnabled)
                            .toggleStyle(LiquidGlassToggleStyle())
                            .onChange(of: isEnabled) { oldValue, newValue in
                                delegate?.isEnabled = newValue
                                sendNotification(
                                    title: "AI Agent \(newValue ? "Activated" : "Deactivated")",
                                    body: newValue ? "I'm watching and ready to help!" : "I'm taking a break."
                                )
                            }
                    }

                    Text("Background AI Agent")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    StatusIndicator(isEnabled: isEnabled)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding()

                // Recent Activities
                ScrollView {
                    VStack(spacing: 12) {
                        if recentActivities.isEmpty {
                            EmptyStateView()
                        } else {
                            ForEach(recentActivities) { activity in
                                ActivityCard(activity: activity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Footer buttons
                HStack(spacing: 16) {
                    ActionButton(icon: "gearshape.fill", title: "Settings") {
                        showingSettings = true
                    }

                    ActionButton(icon: "doc.text.fill", title: "Memory") {
                        openMemoryFile()
                    }

                    ActionButton(icon: "arrow.clockwise", title: "Refresh") {
                        loadRecentActivities()
                    }

                    Spacer()

                    ActionButton(icon: "power", title: "Quit", color: .red) {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            isEnabled = delegate?.isEnabled ?? true
            loadRecentActivities()
            startActivityTimer()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    func loadRecentActivities() {
        // This will be populated by the AgentEngine
        if let engine = delegate?.agentEngine {
            recentActivities = engine.getRecentActivities()
        }
    }

    func startActivityTimer() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            loadRecentActivities()
        }
    }

    func openMemoryFile() {
        let memoryPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".background-ai-agent")
            .appendingPathComponent("memory.md")

        NSWorkspace.shared.open(memoryPath)
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct StatusIndicator: View {
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .shadow(color: isEnabled ? .green : .clear, radius: 4)

            Text(isEnabled ? "Active & Monitoring" : "Paused")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
}

struct ActivityCard: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: activity.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))

                Text(activity.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(activity.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(.tertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Watching and Learning")
                .font(.system(size: 16, weight: .semibold))

            Text("I'll notify you when I find something to help with!")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(color)
            .frame(width: 60)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LiquidGlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            ZStack {
                Capsule()
                    .fill(configuration.isOn ?
                          LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                SettingRow(icon: "eye.fill", title: "Screenshot Monitoring", description: "Capture screenshots when apps open")
                SettingRow(icon: "brain.fill", title: "AI Analysis", description: "Analyze code and provide suggestions")
                SettingRow(icon: "bell.fill", title: "Smart Notifications", description: "Get notified about improvements")
                SettingRow(icon: "doc.fill", title: "Memory System", description: "Learn from your habits")
            }

            Spacer()

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(width: 500, height: 400)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    @State private var isEnabled = true

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(LiquidGlassToggleStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}
