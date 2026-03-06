// =============================================================================
// BRE4CH - Notification Service Extension
// Intercepts push notifications to set accurate badge count
// =============================================================================

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

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

        // Count already delivered (unread) notifications + this new one
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let newBadge = delivered.count + 1
            bestAttemptContent.badge = NSNumber(value: newBadge)
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Fallback: deliver with whatever we have
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
