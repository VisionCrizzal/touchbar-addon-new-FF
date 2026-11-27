//
//  ProtocolMessages.swift
//  touchbar-browser-helper
//

import Foundation

struct IncomingMessage: Decodable, Sendable {
  let type: String?
  let layout: [ComponentSpec]?
  let name: String?
  let values: ComponentUpdateValues?
  let autoPresent: Bool?
  let replaceNative: Bool?
  let fullWidth: Bool?
  let glassStyle: Bool?
}

struct ScrubberItemSpec: Decodable, Equatable, Sendable {
  let id: String
  let label: String
  let symbol: String?
  let favicon: String?
  let active: Bool?
}

struct SegmentSpec: Decodable, Equatable, Sendable {
  let name: String
  let label: String?
  let symbol: String?
  let icon: String?
  let enabled: Bool?
  let width: Double?
}

struct ComponentSpec: Decodable, Sendable {
  let type: String?
  let name: String?
  let label: String?
  let icon: String?
  let symbol: String?
  let color: String?
  let bezelColor: String?
  let enabled: Bool?
  let width: Double?
  let value: Double?
  let size: String?
  let items: [ScrubberItemSpec]?
  let selectedIndex: Int?
  let popoverItems: [ComponentSpec]?
  let segments: [SegmentSpec]?
}

struct ComponentUpdateValues: Decodable, Sendable {
  let label: String?
  let icon: String?
  let symbol: String?
  let color: String?
  let bezelColor: String?
  let enabled: Bool?
  let value: Double?
  let items: [ScrubberItemSpec]?
  let selectedIndex: Int?
}

struct PingResponse: Encodable, Sendable {
  let type: String
  let success: Bool
  let value: String

  init(type: String = "ping", success: Bool = true, value: String = "pong") {
    self.type = type
    self.success = success
    self.value = value
  }
}

struct ErrorResponse: Encodable, Sendable {
  let type: String
  let success: Bool
  let message: String

  init(type: String, success: Bool = false, message: String) {
    self.type = type
    self.success = success
    self.message = message
  }
}

struct ButtonActionMessage: Encodable, Sendable {
  let type: String
  let target: String
  let name: String

  init(type: String = "action", target: String = "button", name: String) {
    self.type = type
    self.target = target
    self.name = name
  }
}

struct SliderActionMessage: Encodable, Sendable {
  let type: String
  let target: String
  let name: String
  let value: Double

  init(type: String = "action", target: String = "slider", name: String, value: Double) {
    self.type = type
    self.target = target
    self.name = name
    self.value = value
  }
}

struct ScrubberActionMessage: Encodable, Sendable {
  let type: String
  let target: String
  let name: String
  let index: Int
  let itemId: String

  init(
    type: String = "action",
    target: String = "scrubber",
    name: String,
    index: Int,
    itemId: String
  ) {
    self.type = type
    self.target = target
    self.name = name
    self.index = index
    self.itemId = itemId
  }
}
