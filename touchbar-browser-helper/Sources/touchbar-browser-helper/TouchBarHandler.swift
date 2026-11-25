//
//  TouchBarHandler.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 08/11/2020.
//

import Cocoa
import CTouchBar

let identifierPrefix = "com.github.visioncrizzal.touchbar-addon-new-ff"

extension NSTouchBarItem.Identifier {
  static let touchbarBrowserGlobal = NSTouchBarItem.Identifier("\(identifierPrefix).global")
  static let touchbarBrowserClose = NSTouchBarItem.Identifier("\(identifierPrefix).close")
}

@MainActor
final class TouchBarHandler: NSObject, NSTouchBarDelegate {
  private var isGlobalItemShown = false
  private var isStripPresented = false
  var autoPresentOnFocus = true
  var replaceNativeTouchBar = true
  var fullWidthMode = false
  private(set) var isFirefoxFrontmost = false
  private(set) var firefoxHasVisibleWindow = true

  var shouldShowForFirefox: Bool {
    isFirefoxFrontmost && firefoxHasVisibleWindow
  }

  var layoutComponents: [TouchBarComponent] = [] {
    didSet {
      updateTouchbarStrip()
      if layoutComponents.isEmpty {
        touchbarStripVisible = false
      } else if shouldShowForFirefox && !touchbarStrip.isVisible && autoPresentOnFocus {
        touchbarStripVisible = true
      }
    }
  }

  private lazy var touchbarStrip: NSTouchBar = {
    let strip = NSTouchBar()
    strip.defaultItemIdentifiers = []
    strip.delegate = self
    return strip
  }()

  var touchbarStripVisible: Bool {
    set {
      if newValue {
        TouchBarHideSystemModalCloseButton(replaceNativeTouchBar)
        if replaceNativeTouchBar {
          NSTouchBar.presentSystemModalTouchBar(
            touchbarStrip,
            placement: fullWidthMode ? 1 : 0,
            systemTrayItemIdentifier: nil
          )
        } else {
          NSTouchBar.presentSystemModalTouchBar(
            touchbarStrip,
            systemTrayItemIdentifier: .touchbarBrowserClose
          )
        }
        isStripPresented = true
      } else if isStripPresented || touchbarStrip.isVisible {
        NSTouchBar.dismissSystemModalTouchBar(touchbarStrip)
        isStripPresented = false
      }
    }
    get {
      touchbarStrip.isVisible
    }
  }

  func applyConfig(autoPresent: Bool?, replaceNative: Bool?, fullWidth: Bool?) {
    let presentationModeChanged =
      (replaceNative != nil && replaceNative != replaceNativeTouchBar) ||
      (fullWidth != nil && fullWidth != fullWidthMode)

    if let autoPresent = autoPresent {
      autoPresentOnFocus = autoPresent
    }
    if let replaceNative = replaceNative {
      replaceNativeTouchBar = replaceNative
    }
    if let fullWidth = fullWidth {
      fullWidthMode = fullWidth
    }

    TouchBarHideSystemModalCloseButton(replaceNativeTouchBar)

    guard shouldShowForFirefox else {
      removeGlobalTouchBarItem()
      return
    }

    if replaceNativeTouchBar {
      removeControlStripOnly()
    } else {
      showGlobalTouchBarItem()
    }

    if !layoutComponents.isEmpty {
      if presentationModeChanged && touchbarStrip.isVisible {
        NSTouchBar.dismissSystemModalTouchBar(touchbarStrip)
        touchbarStripVisible = true
      } else if autoPresentOnFocus && !touchbarStrip.isVisible {
        touchbarStripVisible = true
      }
    }
  }

  func setFirefoxPresentation(frontmost: Bool, hasVisibleWindow: Bool) {
    let wasActive = shouldShowForFirefox
    isFirefoxFrontmost = frontmost
    firefoxHasVisibleWindow = hasVisibleWindow
    let isActive = shouldShowForFirefox

    if isActive {
      if !replaceNativeTouchBar {
        showGlobalTouchBarItem()
      } else {
        removeControlStripOnly()
      }
      if autoPresentOnFocus && !layoutComponents.isEmpty && (!wasActive || !touchbarStrip.isVisible) {
        touchbarStripVisible = true
      }
    } else {
      removeGlobalTouchBarItem()
    }
  }

  func setFirefoxFrontmost(_ frontmost: Bool) {
    setFirefoxPresentation(frontmost: frontmost, hasVisibleWindow: frontmost)
  }

  func updateTouchbarStrip() {
    touchbarStrip.defaultItemIdentifiers = layoutComponents.map { $0.identifier }
  }

  lazy var globalTouchBarItem: NSCustomTouchBarItem = {
    let item = NSCustomTouchBarItem(identifier: .touchbarBrowserGlobal)
    if let img = resolveTouchBarImage(symbol: "globe", icon: nil, accessibilityDescription: "Firefox Touch Bar") {
      item.view = NSButton(image: img, target: self, action: #selector(actionTouchbarButtonToggle))
    } else {
      item.view = NSButton(title: "🌍", target: self, action: #selector(actionTouchbarButtonToggle))
    }
    return item
  }()

  func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
    switch identifier {
    case .touchbarBrowserClose:
      let closeItem = NSCustomTouchBarItem(identifier: .touchbarBrowserClose)
      if let img = resolveTouchBarImage(symbol: "xmark", icon: nil, accessibilityDescription: "Close Touch Bar", pointSize: 13) {
        closeItem.view = NSButton(image: img, target: self, action: #selector(actionTouchbarButtonClose))
      } else {
        closeItem.view = NSButton(title: "Close", target: self, action: #selector(actionTouchbarButtonClose))
      }
      return closeItem
    default:
      if let component = layoutComponents.first(where: { $0.identifier == identifier }) {
        return component.touchBarItem
      }
    }

    return nil
  }

  @objc func actionTouchbarButtonToggle() {
    touchbarStripVisible = !touchbarStripVisible
  }

  @objc func actionTouchbarButtonOpen() {
    touchbarStripVisible = true
  }

  @objc func actionTouchbarButtonClose() {
    touchbarStripVisible = false
  }

  func showGlobalTouchBarItem() {
    guard !isGlobalItemShown else { return }
    NSTouchBarItem.addSystemTrayItem(globalTouchBarItem)
    DFRElementSetControlStripPresenceForIdentifier(.touchbarBrowserGlobal, true)
    isGlobalItemShown = true
  }

  func removeControlStripOnly() {
    guard isGlobalItemShown else { return }
    DFRElementSetControlStripPresenceForIdentifier(.touchbarBrowserGlobal, false)
    NSTouchBarItem.removeSystemTrayItem(globalTouchBarItem)
    isGlobalItemShown = false
  }

  func removeGlobalTouchBarItem() {
    touchbarStripVisible = false
    removeControlStripOnly()
  }
}
