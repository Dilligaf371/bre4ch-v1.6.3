import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Push notification delegate
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // Clear badge on cold start
    clearBadge(application)

    // ── MethodChannel for badge clearing from Dart ──
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.qyber.breach/badge", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "clearBadge" {
          self?.clearBadge(UIApplication.shared)
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Show notifications when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  // Called when user taps a notification
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    clearBadge(UIApplication.shared)
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // Called when app returns from background
  override func applicationWillEnterForeground(_ application: UIApplication) {
    clearBadge(application)
    super.applicationWillEnterForeground(application)
  }

  // Called when app becomes active
  override func applicationDidBecomeActive(_ application: UIApplication) {
    clearBadge(application)
    super.applicationDidBecomeActive(application)
  }

  // ── Centralized badge clearing ──
  // Only resets badge count — does NOT remove delivered notifications
  // so emergency alerts remain visible in the notification center.
  private func clearBadge(_ application: UIApplication) {
    application.applicationIconBadgeNumber = 0
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
  }
}
