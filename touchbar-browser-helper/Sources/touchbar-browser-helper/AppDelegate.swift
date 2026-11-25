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

  override init() {
    let touchbarHandler = TouchBarHandler()
    self.touchbarHandler = touchbarHandler
    self.browserCommunication = BrowserCommunication()
    self.messageHandler = MessageHandler(touchbarHandler: touchbarHandler)
    super.init()
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(appActivatedEvent),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    if let foregroundApp = NSWorkspace.shared.frontmostApplication {
      foremostApplicationChanged(to: foregroundApp)
    }

    let messageHandler = self.messageHandler
    let browserCommunication = self.browserCommunication

    browserCommunication.startListening(
      onMessage: { data in
        messageHandler.processMessageData(data, browserCommunication: browserCommunication)
      },
      onDisconnect: { [weak self] in
        Task { @MainActor in
          self?.touchbarHandler.removeGlobalTouchBarItem()
          NSApp.terminate(nil)
        }
      }
    )
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    touchbarHandler.removeGlobalTouchBarItem()
  }

  @objc func appActivatedEvent(notification: Notification) {
    guard let foregroundApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }

    foremostApplicationChanged(to: foregroundApp)
  }

  func foremostApplicationChanged(to foregroundApp: NSRunningApplication) {
    let isFirefox = foregroundApp.bundleIdentifier.map {
      Self.firefoxBundleIdentifiers.contains($0)
    } ?? false
    touchbarHandler.setFirefoxFrontmost(isFirefox)
  }
}
