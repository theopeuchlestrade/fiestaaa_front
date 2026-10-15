import Flutter
import UIKit
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeCalendarPlugin") {
      NativeCalendarPlugin.register(with: registrar)
    }
  }
}

/// EventKitUI owns the save confirmation; no calendar-store access is requested.
final class NativeCalendarPlugin: NSObject, FlutterPlugin, EKEventEditViewDelegate {
  private let registrar: FlutterPluginRegistrar
  private var pendingResult: FlutterResult?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fiestaaa/calendar", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NativeCalendarPlugin(registrar: registrar), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      if #available(iOS 17.0, *) { result(true) } else { result(false) }
    case "openEditor":
      guard #available(iOS 17.0, *) else {
        result("unavailable")
        return
      }
      guard pendingResult == nil else {
        result(FlutterError(code: "busy", message: "Calendar editor already open", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let start = args["startMillis"] as? NSNumber,
            let end = args["endMillis"] as? NSNumber,
            end.doubleValue > start.doubleValue,
            let zoneName = args["timeZone"] as? String,
            let zone = TimeZone(identifier: zoneName) else {
        result(FlutterError(code: "invalid_event", message: "Invalid calendar event", details: nil))
        return
      }
      guard let presenter = registrar.viewController,
            presenter.viewIfLoaded?.window != nil,
            presenter.presentedViewController == nil else {
        result("unavailable")
        return
      }
      let store = EKEventStore()
      let event = EKEvent(eventStore: store)
      event.title = title
      event.notes = args["description"] as? String
      event.location = args["location"] as? String
      event.startDate = Date(timeIntervalSince1970: start.doubleValue / 1000)
      event.endDate = Date(timeIntervalSince1970: end.doubleValue / 1000)
      event.timeZone = zone
      let editor = EKEventEditViewController()
      editor.eventStore = store
      editor.event = event
      editor.editViewDelegate = self
      editor.isModalInPresentation = true
      pendingResult = result
      presenter.present(editor, animated: true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func eventEditViewController(_ controller: EKEventEditViewController,
                               didCompleteWith action: EKEventEditViewAction) {
    let callback = pendingResult
    pendingResult = nil
    controller.dismiss(animated: true) {
      callback?(action == .saved ? "saved" : "cancelled")
    }
  }
}
