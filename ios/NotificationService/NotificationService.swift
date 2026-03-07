// =============================================================================
// BRE4CH - Notification Service Extension
// Intercepts push notifications to:
//   1. Set accurate badge count
//   2. Set interruption level based on severity keywords
//   3. Use system default sounds (custom sounds removed)
// =============================================================================

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    // EXTREME keywords → critical interruption level
    private let extremeKeywords = [
        "nuclear", "radiological", "wmd", "chemical weapon",
        "mass casualty", "nato article 5",
        "missile", "ballistic", "warhead", "icbm",
        "صاروخ", "نووي", "سلاح كيميائي", "رأس حربي",
    ]

    // SEVERE keywords → time-sensitive interruption level
    private let severeKeywords = [
        "killed", "strike", "attack", "war", "breaking",
        "drone", "shot down", "friendly fire",
        "airport shut", "airport hit",
        "hezbollah", "retaliation", "sunk",
        "evacuation", "evacuate",
        "هجوم", "طائرة مسيرة", "ضربة", "قتل", "حرب", "إجلاء",
    ]

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // ── Detect severity from title + body ────────────────────
        let title = bestAttemptContent.title.lowercased()
        let body = bestAttemptContent.body.lowercased()
        let combined = "\(title) \(body)"

        let isExtreme = extremeKeywords.contains { combined.contains($0) }
        let isSevere = !isExtreme && severeKeywords.contains { combined.contains($0) }

        // ── Set sound + interruption level ────────────────────────
        // Always use system default sound. Severity only affects
        // interruption level (critical > time-sensitive > active).
        bestAttemptContent.sound = UNNotificationSound.default

        if isExtreme {
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .critical
            }
            // Critical sound at full volume (bypasses silent mode)
            if #available(iOSApplicationExtension 12.0, *) {
                bestAttemptContent.sound = UNNotificationSound.defaultCritical
            }
        } else if isSevere {
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }
        } else {
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .active
            }
        }

        // ── Badge count ──────────────────────────────────────────
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let newBadge = delivered.count + 1
            bestAttemptContent.badge = NSNumber(value: newBadge)
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
