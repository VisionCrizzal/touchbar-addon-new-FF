//
//  BrowserCommunication.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 08/11/2020.
//

import Foundation

final class BrowserCommunication: @unchecked Sendable {
  private static let maxMessageSize = 10 * 1024 * 1024

  private let readQueue = DispatchQueue(
    label: "com.github.visioncrizzal.touchbar-addon-new-ff.stdin",
    qos: .userInitiated
  )
  private let writeQueue = DispatchQueue(
    label: "com.github.visioncrizzal.touchbar-addon-new-ff.stdout",
    qos: .userInitiated
  )

  func sendMessage<T: Encodable & Sendable>(_ message: T) {
    let encoder = JSONEncoder()
    guard let messageData = try? encoder.encode(message) else {
      NSLog("Failed to encode outgoing message")
      return
    }

    let length = UInt32(messageData.count).littleEndian
    let frame = withUnsafeBytes(of: length) { Data($0) } + messageData

    writeQueue.async {
      do {
        try FileHandle.standardOutput.write(contentsOf: frame)
      } catch {
        NSLog("Failed to write native message to stdout: %@", error.localizedDescription)
      }
    }
  }

  func startListening(
    onMessage: @escaping @Sendable (Data) -> Void,
    onDisconnect: @escaping @Sendable () -> Void
  ) {
    readQueue.async {
      let input = FileHandle.standardInput

      while true {
        guard let lengthData = Self.readExact(4, from: input) else {
          NSLog("stdin closed (EOF), exiting")
          onDisconnect()
          return
        }

        let rawLength = lengthData.withUnsafeBytes {
          $0.loadUnaligned(as: UInt32.self)
        }
        let messageSize = Int(UInt32(littleEndian: rawLength))

        if messageSize == 0 {
          continue
        }

        guard messageSize <= Self.maxMessageSize else {
          NSLog("Message size %d exceeds limit, exiting", messageSize)
          onDisconnect()
          return
        }

        guard let payload = Self.readExact(messageSize, from: input) else {
          NSLog("stdin closed mid-message (EOF), exiting")
          onDisconnect()
          return
        }

        onMessage(payload)
      }
    }
  }

  private static func readExact(_ count: Int, from handle: FileHandle) -> Data? {
    if count == 0 {
      return Data()
    }

    var buffer = Data()
    buffer.reserveCapacity(count)

    while buffer.count < count {
      do {
        guard let chunk = try handle.read(upToCount: count - buffer.count), !chunk.isEmpty else {
          return nil
        }
        buffer.append(chunk)
      } catch {
        NSLog("Error reading from stdin: %@", error.localizedDescription)
        return nil
      }
    }

    return buffer
  }
}
