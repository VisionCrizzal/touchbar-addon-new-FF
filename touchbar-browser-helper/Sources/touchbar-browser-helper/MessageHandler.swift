//
//  MessageHandler.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 08/11/2020.
//

import Cocoa
import Foundation

final class MessageHandler: Sendable {
  let touchbarHandler: TouchBarHandler

  init(touchbarHandler: TouchBarHandler) {
    self.touchbarHandler = touchbarHandler
  }

  func processMessageData(_ data: Data, browserCommunication: BrowserCommunication) {
    let decoder = JSONDecoder()
    guard let message = try? decoder.decode(IncomingMessage.self, from: data) else {
      browserCommunication.sendMessage(
        ErrorResponse(type: "null", message: "Could not parse message as json")
      )
      return
    }

    guard let messageType = message.type else {
      browserCommunication.sendMessage(
        ErrorResponse(type: "null", message: "Message missing type")
      )
      return
    }

    NSLog("Process message of type '%@'", messageType)

    switch messageType {
    case "ping":
      browserCommunication.sendMessage(PingResponse())
    case "change_layout":
      let layout = message.layout ?? []
      Task { @MainActor in
        self.handleChangeLayout(layout, browserCommunication: browserCommunication)
      }
    case "update_item":
      let name = message.name
      let values = message.values
      Task { @MainActor in
        self.handleUpdateItem(name: name, values: values)
      }
    case "dismiss_touchbar":
      Task { @MainActor in
        self.touchbarHandler.touchbarStripVisible = false
      }
    case "set_config":
      let autoPresent = message.autoPresent
      let replaceNative = message.replaceNative
      let fullWidth = message.fullWidth
      Task { @MainActor in
        self.touchbarHandler.applyConfig(
          autoPresent: autoPresent,
          replaceNative: replaceNative,
          fullWidth: fullWidth
        )
      }
    default:
      NSLog("Message handler error on type %@: Unknown message type", messageType)
      browserCommunication.sendMessage(
        ErrorResponse(type: messageType, message: "Unknown message type")
      )
    }
  }

  @MainActor
  func handleChangeLayout(_ layout: [ComponentSpec], browserCommunication: BrowserCommunication) {
    let components = layout.compactMap {
      generateComponent(spec: $0, browserCommunication: browserCommunication)
    }
    touchbarHandler.layoutComponents = components
  }

  @MainActor
  func handleUpdateItem(name: String?, values: ComponentUpdateValues?) {
    guard let name = name, let values = values else {
      return
    }

    guard let component = touchbarHandler.layoutComponents.first(where: { $0.name == name }) else {
      return
    }

    switch component.component {
    case .button:
      let bezelHex = values.bezelColor ?? values.color
      let resolvedImage =
        (values.symbol != nil || values.icon != nil)
        ? resolveTouchBarImage(
          symbol: values.symbol,
          icon: values.icon,
          accessibilityDescription: values.label ?? name
        )
        : nil

      if let buttonItem = component.touchBarItem as? NSButtonTouchBarItem {
        if let newLabel = values.label {
          buttonItem.title = newLabel
        }
        if let resolvedImage = resolvedImage {
          buttonItem.image = resolvedImage
        }
        if let bezelHex = bezelHex {
          buttonItem.bezelColor = bezelHex.isEmpty ? nil : NSColor.from(hex: bezelHex)
        }
        if let enabled = values.enabled {
          buttonItem.isEnabled = enabled
        }
      } else if let customItem = component.touchBarItem as? NSCustomTouchBarItem,
                let button = customItem.view as? NSButton {
        if let newLabel = values.label {
          button.title = newLabel
        }
        if let resolvedImage = resolvedImage {
          button.image = resolvedImage
        }
        if let bezelHex = bezelHex {
          button.bezelColor = bezelHex.isEmpty ? nil : NSColor.from(hex: bezelHex)
        }
        if let enabled = values.enabled {
          button.isEnabled = enabled
        }
      }

    case .slider:
      guard let slider = component.touchBarItem as? NSSliderTouchBarItem else {
        return
      }

      if let newValue = values.value, newValue.isFinite {
        slider.slider.doubleValue = min(max(newValue, 0.0), 1.0)
      }

      if let newLabel = values.label {
        slider.label = newLabel
      }

      if let newColor = values.color {
        slider.slider.trackFillColor = NSColor.from(hex: newColor)
      }

    case .label:
      guard let customItem = component.touchBarItem as? NSCustomTouchBarItem,
            let textField = customItem.view as? NSTextField else {
        return
      }

      if let newLabel = values.label {
        textField.stringValue = newLabel
      }

      if let newColor = values.color {
        textField.textColor = NSColor.from(hex: newColor) ?? .labelColor
      }

    case .scrubber:
      if values.items != nil || values.selectedIndex != nil {
        _ = component.touchBarItem
        component.scrubberController?.update(
          items: values.items,
          selectedIndex: values.selectedIndex
        )
      }

    case .spacer, .popover, .segmented:
      break
    }
  }

  @MainActor
  func generateComponent(spec: ComponentSpec, browserCommunication: BrowserCommunication) -> TouchBarComponent? {
    guard let type = spec.type, let name = spec.name else {
      return nil
    }

    switch type {
    case "button":
      let bezelColor = (spec.bezelColor ?? spec.color).flatMap { NSColor.from(hex: $0) }
      let width = spec.width.map { CGFloat($0) }
      return TouchBarComponent(
        name: name,
        component: .button(
          label: spec.label ?? "",
          icon: spec.icon,
          symbol: spec.symbol,
          bezelColor: bezelColor,
          enabled: spec.enabled ?? true,
          width: width
        ),
        browserCommunication: browserCommunication
      )

    case "slider":
      let value = (spec.value?.isFinite == true) ? (spec.value ?? 0.0) : 0.0
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      return TouchBarComponent(
        name: name,
        component: .slider(label: spec.label, value: value, color: color),
        browserCommunication: browserCommunication
      )

    case "label":
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      return TouchBarComponent(
        name: name,
        component: .label(text: spec.label ?? "", color: color),
        browserCommunication: browserCommunication
      )

    case "spacer":
      let spacerSize: TouchBarComponent.SpacerSize
      switch spec.size {
      case "large":
        spacerSize = .large
      case "flexible":
        spacerSize = .flexible
      default:
        spacerSize = .small
      }
      return TouchBarComponent(
        name: name,
        component: .spacer(size: spacerSize),
        browserCommunication: browserCommunication
      )

    case "scrubber":
      return TouchBarComponent(
        name: name,
        component: .scrubber(items: spec.items ?? [], selectedIndex: spec.selectedIndex),
        browserCommunication: browserCommunication
      )

    case "popover":
      let bezelColor = (spec.bezelColor ?? spec.color).flatMap { NSColor.from(hex: $0) }
      let children = (spec.popoverItems ?? []).compactMap {
        generateComponent(spec: $0, browserCommunication: browserCommunication)
      }
      return TouchBarComponent(
        name: name,
        component: .popover(
          label: spec.label ?? "",
          icon: spec.icon,
          symbol: spec.symbol,
          bezelColor: bezelColor,
          children: children
        ),
        browserCommunication: browserCommunication
      )

    case "segmented":
      return TouchBarComponent(
        name: name,
        component: .segmented(segments: spec.segments ?? []),
        browserCommunication: browserCommunication
      )

    default:
      return nil
    }
  }
}
