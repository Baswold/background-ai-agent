import Foundation
import EventKit
import UserNotifications

class SmartReminders {
    private let eventStore = EKEventStore()
    private var reminders: [SmartReminder] = []
    private var activityCallback: ((Activity) -> Void)?

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        requestCalendarAccess()
        scheduleContextualReminders()
        print("⏰ Smart reminders started")
    }

    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .reminder) { granted, error in
            if granted {
                print("✅ Calendar access granted")
                self.syncWithCalendar()
            }
        }
    }

    private func syncWithCalendar() {
        // Fetch upcoming events
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: tomorrow,
            calendars: calendars
        )

        let events = eventStore.events(matching: predicate)

        for event in events.prefix(5) {
            analyzeEvent(event)
        }
    }

    private func analyzeEvent(_ event: EKEvent) {
        // Check if it's a meeting
        if event.hasAttendees {
            // Remind to prepare
            let prepTime = event.startDate.addingTimeInterval(-15 * 60) // 15 min before

            if prepTime > Date() {
                createReminder(
                    title: "Prepare for: \(event.title ?? "Meeting")",
                    triggerDate: prepTime,
                    context: "Meeting prep"
                )
            }
        }

        // Check for GitHub PRs in meeting notes
        if let notes = event.notes, notes.contains("github.com") {
            let activity = Activity(
                title: "PR Review Meeting Detected",
                description: "Meeting about: \(event.title ?? "Unknown")",
                type: .githubPR
            )
            activityCallback?(activity)
        }
    }

    private func createReminder(title: String, triggerDate: Date, context: String) {
        let reminder = SmartReminder(
            id: UUID(),
            title: title,
            triggerDate: triggerDate,
            context: context
        )

        reminders.append(reminder)

        // Schedule notification
        let content = UNMutableNotificationContent()
        content.title = "Smart Reminder"
        content.body = title
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: triggerDate.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        print("⏰ Reminder scheduled: \(title)")
    }

    func createContextualReminder(basedOn activity: Activity) {
        // Create smart reminders based on what user is doing
        if activity.type == .vsCodeFix {
            // Remind to commit code after fixing
            createReminder(
                title: "Don't forget to commit your fixes!",
                triggerDate: Date().addingTimeInterval(30 * 60),
                context: "Code fix reminder"
            )
        } else if activity.type == .githubPR {
            // Remind to check PR status
            createReminder(
                title: "Check PR review status",
                triggerDate: Date().addingTimeInterval(4 * 60 * 60),
                context: "PR follow-up"
            )
        }
    }

    private func scheduleContextualReminders() {
        // Remind about breaks during deep work
        Timer.scheduledTimer(withTimeInterval: 50 * 60, repeats: true) { [weak self] _ in
            self?.suggestBreak()
        }
    }

    private func suggestBreak() {
        let activity = Activity(
            title: "Time for a Break",
            description: "You've been working for a while. Take a 5-minute break!",
            type: .learning
        )
        activityCallback?(activity)
    }
}

struct SmartReminder: Identifiable {
    let id: UUID
    let title: String
    let triggerDate: Date
    let context: String
    var completed: Bool = false
}
