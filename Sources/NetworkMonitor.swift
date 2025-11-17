import Foundation
import Network

class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var activityCallback: ((Activity) -> Void)?
    private var currentConnection: NWPath.Status = .satisfied

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity

        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }

        monitor.start(queue: queue)
        print("🌐 Network monitor started")
    }

    func stop() {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newStatus = path.status

        if newStatus != currentConnection {
            currentConnection = newStatus

            switch newStatus {
            case .satisfied:
                notifyConnected(path)
            case .unsatisfied:
                notifyDisconnected()
            case .requiresConnection:
                notifyRequiresConnection()
            @unknown default:
                break
            }
        }

        // Check connection type
        if path.usesInterfaceType(.wifi) {
            checkWiFiQuality(path)
        } else if path.usesInterfaceType(.cellular) {
            notifyCellularUsage()
        }

        // Check if VPN is active
        if path.usesInterfaceType(.other) {
            checkVPNStatus()
        }
    }

    private func notifyConnected(_ path: NWPath) {
        var connectionType = "Unknown"

        if path.usesInterfaceType(.wifi) {
            connectionType = "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = "Ethernet"
        }

        let activity = Activity(
            title: "Internet Connected",
            description: "Connected via \(connectionType)",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func notifyDisconnected() {
        let activity = Activity(
            title: "⚠️ Internet Disconnected",
            description: "No internet connection detected",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func notifyRequiresConnection() {
        let activity = Activity(
            title: "Connection Required",
            description: "Network requires additional setup",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func checkWiFiQuality(_ path: NWPath) {
        // Could expand to check signal strength, etc.
        if path.isExpensive {
            let activity = Activity(
                title: "📶 Expensive Connection",
                description: "You're on a metered connection",
                type: .learning
            )
            activityCallback?(activity)
        }
    }

    private func notifyCellularUsage() {
        let activity = Activity(
            title: "📱 Using Cellular Data",
            description: "Connected via cellular network",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func checkVPNStatus() {
        // VPN detection
        let activity = Activity(
            title: "🔒 VPN Detected",
            description: "You appear to be using a VPN",
            type: .learning
        )
        activityCallback?(activity)
    }
}
