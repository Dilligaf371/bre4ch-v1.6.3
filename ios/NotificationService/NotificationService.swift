// =============================================================================
// BRE4CH - Notification Service Extension
// Intercepts push notifications to:
//   1. Set accurate badge count
//   2. Assign alert sound based on severity keywords (siren / radar)
// =============================================================================

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    // EXTREME → siren (police siren, looped feeling via critical)
    private let extremeKeywords = [
        "nuclear", "radiological", "wmd", "chemical weapon",
        "mass casualty", "nato article 5",
        "missile", "ballistic", "warhead", "icbm",
        "صاروخ", "نووي", "سلاح كيميائي", "رأس حربي",
    ]

    // SEVERE → radar ping
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

        // ── Set sound ────────────────────────────────────────────
        if isExtreme {
            // Try critical sound first (bypasses silent mode / DND)
            // Falls back to regular named sound if critical entitlement is missing
            if #available(iOSApplicationExtension 12.0, *) {
                bestAttemptContent.sound = UNNotificationSound.criticalSoundNamed(
                    UNNotificationSoundName("siren.wav"),
                    withAudioVolume: 1.0
                )
            } else {
                bestAttemptContent.sound = UNNotificationSound(
                    named: UNNotificationSoundName("siren.wav")
                )
            }
            // Mark as critical via interruption level
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .critical
            }
        } else if isSevere {
            bestAttemptContent.sound = UNNotificationSound(
                named: UNNotificationSoundName("radar.wav")
            )
            if #available(iOSApplicationExtension 15.0, *) {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }
        } else {
            bestAttemptContent.sound = UNNotificationSound.default
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
