//
//  NSColor+webhex.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 11/11/2020.
//

import Cocoa

extension NSColor {
  static func from(hex: String) -> NSColor? {
    var val = hex
    if val.hasPrefix("#") {
      val.removeFirst()
    }

    if !val.filter({ !$0.isHexDigit }).isEmpty {
      return nil
    }

    if val.count == 3 {
      var expanded = ""
      for c in val {
        expanded += "\(c)\(c)"
      }
      val = expanded
    }

    if val.count != 6 {
      return nil
    }

    guard let rgb = Int32(val, radix: 16) else {
      return nil
    }

    let r = (rgb >> 16) & 0xFF
    let g = (rgb >> 8) & 0xFF
    let b = rgb & 0xFF

    let rFloat = CGFloat(r) / 255.0
    let gFloat = CGFloat(g) / 255.0
    let bFloat = CGFloat(b) / 255.0

    return NSColor(srgbRed: rFloat, green: gFloat, blue: bFloat, alpha: 1.0)
  }
}
