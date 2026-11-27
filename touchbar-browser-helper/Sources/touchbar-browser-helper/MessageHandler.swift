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
      let glassStyle = message.glassStyle
      Task { @MainActor in
        let glassChanged = self.touchbarHandler.applyConfig(
          autoPresent: autoPresent,
          replaceNative: replaceNative,
          fullWidth: fullWidth,
          glassStyle: glassStyle
        )
        if glassChanged && !self.touchbarHandler.lastLayoutSpecs.isEmpty {
          let components = self.touchbarHandler.lastLayoutSpecs.compactMap {
            self.generateComponent(
              spec: $0,
              glassStyle: self.touchbarHandler.useGlassStyle,
              browserCommunication: browserCommunication
            )
          }
          self.touchbarHandler.layoutComponents = components
        }
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
    touchbarHandler.lastLayoutSpecs = layout
    let existing = touchbarHandler.layoutComponents

    if !layout.isEmpty && existing.count == layout.count &&
       zip(existing, layout).allSatisfy({ $0.matchesStructure(of: $1) }) {
      for (component, spec) in zip(existing, layout) {
        component.applySpecInPlace(spec, animated: true)
      }
      if touchbarHandler.shouldShowForFirefox && !touchbarHandler.touchbarStripVisible && touchbarHandler.autoPresentOnFocus {
        touchbarHandler.touchbarStripVisible = true
      }
      return
    }

    let components = layout.compactMap {
      generateComponent(
        spec: $0,
        glassStyle: touchbarHandler.useGlassStyle,
        browserCommunication: browserCommunication
      )
    }
    touchbarHandler.layoutComponents = components

    if !components.isEmpty && touchbarHandler.shouldShowForFirefox {
      touchbarHandler.animateLayoutEntrance()
    }
  }

  @MainActor
  func handleUpdateItem(name: String?, values: ComponentUpdateValues?) {
    guard let name = name, let values = values else {
      return
    }

    guard let component = touchbarHandler.layoutComponents.first(where: { $0.name == name }) else {
      return
    }

    component.applyUpdateValues(values)
  }

  @MainActor
  func generateComponent(
    spec: ComponentSpec,
    glassStyle: Bool,
    browserCommunication: BrowserCommunication
  ) -> TouchBarComponent? {
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
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "slider":
      let value = (spec.value?.isFinite == true) ? (spec.value ?? 0.0) : 0.0
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      return TouchBarComponent(
        name: name,
        component: .slider(label: spec.label, value: value, color: color),
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "label":
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      return TouchBarComponent(
        name: name,
        component: .label(text: spec.label ?? "", color: color),
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "spacer":
      let spacerSize = TouchBarComponent.SpacerSize.from(spec.size)
      return TouchBarComponent(
        name: name,
        component: .spacer(size: spacerSize),
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "scrubber":
      return TouchBarComponent(
        name: name,
        component: .scrubber(items: spec.items ?? [], selectedIndex: spec.selectedIndex),
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "popover":
      let bezelColor = (spec.bezelColor ?? spec.color).flatMap { NSColor.from(hex: $0) }
      let children = (spec.popoverItems ?? []).compactMap {
        generateComponent(
          spec: $0,
          glassStyle: glassStyle,
          browserCommunication: browserCommunication
        )
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
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    case "segmented":
      return TouchBarComponent(
        name: name,
        component: .segmented(segments: spec.segments ?? []),
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )

    default:
      return nil
    }
  }
}
