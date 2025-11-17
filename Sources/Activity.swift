import Foundation
import SwiftUI

struct Activity: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let title: String
    let description: String
    let type: ActivityType
    var iconName: String { type.icon }
    var icon: String { iconName }
    var colors: [Color] { type.colors }

    init(id: UUID = UUID(), timestamp: Date = Date(), title: String, description: String, type: ActivityType) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.type = type
    }
}

enum ActivityType: String, Codable {
    case vsCodeFix = "vscode_fix"
    case browserAction = "browser_action"
    case githubPR = "github_pr"
    case formFilled = "form_filled"
    case screenshot = "screenshot"
    case learning = "learning"

    var icon: String {
        switch self {
        case .vsCodeFix:
            return "hammer.fill"
        case .browserAction:
            return "safari.fill"
        case .githubPR:
            return "arrow.triangle.pull"
        case .formFilled:
            return "doc.text.fill"
        case .screenshot:
            return "camera.fill"
        case .learning:
            return "brain.head.profile"
        }
    }

    var colors: [Color] {
        switch self {
        case .vsCodeFix:
            return [.blue, .cyan]
        case .browserAction:
            return [.purple, .pink]
        case .githubPR:
            return [.orange, .red]
        case .formFilled:
            return [.green, .mint]
        case .screenshot:
            return [.indigo, .blue]
        case .learning:
            return [.pink, .purple]
        }
    }
}
