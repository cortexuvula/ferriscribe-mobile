import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var captureOverlay: UIView?
  private let nativeChannelName = "com.ferriscribe.mobile/native"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Exclude the app data directories from iCloud backup BEFORE anything
    // writes to them, so the SQLCipher DB and any future temp files are
    // covered regardless of when they are created.
    excludeAppDataFromBackup()

    // Block screen recording by overlaying an opaque cover whenever the OS
    // reports a capture in progress.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeChannel(with: engineBridge.pluginRegistry)
  }

  // MARK: - Native method channel

  private func registerNativeChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: nativeChannelName) else { return }
    let channel = FlutterMethodChannel(
      name: nativeChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(false)
        return
      }
      result(self?.excludeFromBackup(path: path) ?? false)
    }
  }

  // MARK: - Screen-capture protection

  @objc private func screenCaptureChanged() {
    if isAnyScreenCaptured {
      showCaptureOverlay()
    } else {
      hideCaptureOverlay()
    }
  }

  private var isAnyScreenCaptured: Bool {
    for screen in UIScreen.screens where screen.isCaptured {
      return true
    }
    return false
  }

  private func showCaptureOverlay() {
    guard captureOverlay == nil, let window = keyWindow else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.10, alpha: 1.0)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    blur.frame = overlay.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.addSubview(blur)
    window.addSubview(overlay)
    captureOverlay = overlay
  }

  private func hideCaptureOverlay() {
    captureOverlay?.removeFromSuperview()
    captureOverlay = nil
  }

  private var keyWindow: UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows where window.isKeyWindow {
        return window
      }
    }
    return nil
  }

  // MARK: - Backup exclusion

  private func excludeAppDataFromBackup() {
    let fm = FileManager.default
    var dirs: [URL] = []
    if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
      dirs.append(docs)
    }
    if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      dirs.append(support)
    }
    if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
      dirs.append(caches)
    }
    dirs.append(fm.temporaryDirectory)
    for url in dirs {
      _ = excludeFromBackup(path: url.path)
    }
  }

  @discardableResult
  private func excludeFromBackup(path: String) -> Bool {
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
      return true
    } catch {
      return false
    }
  }
}
