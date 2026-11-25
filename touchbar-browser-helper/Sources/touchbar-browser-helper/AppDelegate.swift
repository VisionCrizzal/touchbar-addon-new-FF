//
//  AppDelegate.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 07/11/2020.
//

import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let firefoxBundleIdentifiers: Set<String> = [
    "org.mozilla.firefox",
    "org.mozilla.firefoxdeveloperedition",
    "org.mozilla.nightly",
  ]

  let touchbarHandler: TouchBarHandler
  let browserCommunication: BrowserCommunication
  let messageHandler: MessageHandler
  private var windowPresenceTimer: Timer?

  override init() {
    let touchbarHandler = TouchBarHandler()
    self.touchbarHandler = touchbarHandler
    self.browserCommunication = BrowserCommunication()
    self.messageHandler = MessageHandler(touchbarHandler: touchbarHandler)
    super.init()
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let center = NSWorkspace.shared.notificationCenter
    let workspaceEvents: [(NSNotification.Name, Selector)] = [
      (NSWorkspace.didActivateApplicationNotification, #selector(workspaceFocusChanged)),
      (NSWorkspace.didDeactivateApplicationNotification, #selector(workspaceFocusChanged)),
      (NSWorkspace.didHideApplicationNotification, #selector(workspaceFocusChanged)),
      (NSWorkspace.didUnhideApplicationNotification, #selector(workspaceFocusChanged)),
      (NSWorkspace.didTerminateApplicationNotification, #selector(workspaceFocusChanged)),
      (NSWorkspace.activeSpaceDidChangeNotification, #selector(workspaceFocusChanged)),
    ]

    for (name, selector) in workspaceEvents {
      center.addObserver(self, selector: selector, name: name, object: nil)
    }

    syncFirefoxPresentationState()

    let messageHandler = self.messageHandler
    let browserCommunication = self.browserCommunication

    browserCommunication.startListening(
      onMessage: { data in
        messageHandler.processMessageData(data, browserCommunication: browserCommunication)
      },
      onDisconnect: { [weak self] in
        Task { @MainActor in
          self?.stopWindowPresenceMonitor()
          self?.touchbarHandler.removeGlobalTouchBarItem()
          NSApp.terminate(nil)
        }
      }
    )
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    stopWindowPresenceMonitor()
    touchbarHandler.removeGlobalTouchBarItem()
  }

  @objc func workspaceFocusChanged(notification: Notification) {
    if notification.name == NSWorkspace.didHideApplicationNotification,
       let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
       isFirefoxApp(app) {
      stopWindowPresenceMonitor()
      touchbarHandler.setFirefoxPresentation(frontmost: false, hasVisibleWindow: false)
      return
    }

    syncFirefoxPresentationState()
  }

  private func isFirefoxApp(_ app: NSRunningApplication?) -> Bool {
    guard let bundleID = app?.bundleIdentifier else { return false }
    return Self.firefoxBundleIdentifiers.contains(bundleID)
  }

  private func syncFirefoxPresentationState() {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          isFirefoxApp(frontApp),
          !frontApp.isHidden else {
      stopWindowPresenceMonitor()
      touchbarHandler.setFirefoxPresentation(frontmost: false, hasVisibleWindow: false)
      return
    }

    let hasWindow = Self.applicationHasVisibleWindow(pid: frontApp.processIdentifier)
    touchbarHandler.setFirefoxPresentation(frontmost: true, hasVisibleWindow: hasWindow)
    startWindowPresenceMonitorIfNeeded()
  }

  private func startWindowPresenceMonitorIfNeeded() {
    guard windowPresenceTimer == nil else { return }
    let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.syncFirefoxPresentationState()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    windowPresenceTimer = timer
  }

  private func stopWindowPresenceMonitor() {
    windowPresenceTimer?.invalidate()
    windowPresenceTimer = nil
  }

  private static func applicationHasVisibleWindow(pid: pid_t) -> Bool {
    guard let windowList = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] else {
      return true
    }

    for info in windowList {
      guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
            ownerPID == pid else {
        continue
      }

      let layer = (info[kCGWindowLayer as String] as? Int) ?? -1
      guard layer == 0 else { continue }

      if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0 {
        continue
      }

      if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
         let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
         rect.width >= 100,
         rect.height >= 100 {
        return true
      }
    }

    return false
  }
}
