import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS 无公开音量键 API；通过 MPVolumeView + outputVolume 观察实现翻页（阅读类 App 常用做法）。
private final class IOSVolumeKeyHandler: NSObject {
  private let channel: FlutterMethodChannel
  private var enabled = false
  private var volumeView: MPVolumeView?
  private var observing = false
  private var lastVolume: Float = 0.5
  private var resettingVolume = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "cm/volkeys", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "setEnabled":
        let on = call.arguments as? Bool ?? false
        self.setEnabled(on)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setEnabled(_ on: Bool) {
    enabled = on
    if on {
      startObserving()
    } else {
      stopObserving()
    }
  }

  private func startObserving() {
    if observing { return }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setActive(true)
    } catch {}
    lastVolume = session.outputVolume
    ensureVolumeViewAttached()
    session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
    observing = true
  }

  private func ensureVolumeViewAttached() {
    if volumeView == nil {
      let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
      view.clipsToBounds = true
      view.isUserInteractionEnabled = false
      volumeView = view
    }
    guard let view = volumeView, view.superview == nil else { return }
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: { $0.isKeyWindow })
      ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first
    window?.addSubview(view)
  }

  private func stopObserving() {
    guard observing else { return }
    AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
    observing = false
    volumeView?.removeFromSuperview()
    volumeView = nil
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard enabled, keyPath == "outputVolume", !resettingVolume else { return }
    let newVolume = AVAudioSession.sharedInstance().outputVolume
    if newVolume > lastVolume + 0.001 {
      channel.invokeMethod("volUp", arguments: nil)
    } else if newVolume < lastVolume - 0.001 {
      channel.invokeMethod("volDown", arguments: nil)
    }
    lastVolume = newVolume
    if newVolume <= 0.01 || newVolume >= 0.99 {
      resetVolume(to: 0.5)
    }
  }

  private func resetVolume(to value: Float) {
    ensureVolumeViewAttached()
    guard let view = volumeView else { return }
    resettingVolume = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      defer { self.resettingVolume = false }
      self.ensureVolumeViewAttached()
      for subview in view.subviews {
        if let slider = subview as? UISlider {
          slider.value = value
          self.lastVolume = value
          break
        }
      }
    }
  }

  deinit {
    if observing {
      AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var volumeHandler: IOSVolumeKeyHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IOSVolumeKeyHandler") {
      volumeHandler = IOSVolumeKeyHandler(messenger: registrar.messenger())
    }
  }
}
