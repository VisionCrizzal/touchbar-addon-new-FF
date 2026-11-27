//
//  GlassStyle.swift
//  touchbar-browser-helper
//

import Cocoa
import QuartzCore

@MainActor
enum TouchBarMotion {
  static var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  static func centeredScaleTransform(bounds: CGRect, scale: CGFloat) -> CATransform3D {
    let cx = bounds.midX
    let cy = bounds.midY
    var transform = CATransform3DIdentity
    transform = CATransform3DTranslate(transform, cx, cy, 0)
    transform = CATransform3DScale(transform, scale, scale, 1)
    transform = CATransform3DTranslate(transform, -cx, -cy, 0)
    return transform
  }

  static func animateScale(_ layer: CALayer, to scale: CGFloat) {
    guard !reduceMotion else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layer.transform = CATransform3DIdentity
      CATransaction.commit()
      return
    }

    let bounds = layer.bounds
    guard bounds.width > 0, bounds.height > 0 else { return }

    let currentTransform = layer.presentation()?.transform ?? layer.transform
    let targetTransform = scale == 1.0
      ? CATransform3DIdentity
      : centeredScaleTransform(bounds: bounds, scale: scale)

    let anim = CASpringAnimation(keyPath: "transform")
    anim.fromValue = NSValue(caTransform3D: currentTransform)
    anim.toValue = NSValue(caTransform3D: targetTransform)
    anim.stiffness = scale == 1.0 ? 380 : 460
    anim.damping = scale == 1.0 ? 26 : 30
    anim.mass = 1.0
    anim.duration = min(anim.settlingDuration, 0.28)
    anim.isRemovedOnCompletion = true

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.transform = targetTransform
    CATransaction.commit()

    layer.add(anim, forKey: "touchbar.springScale")
  }

  static func animateEntrance(_ layer: CALayer?) {
    guard let layer = layer else { return }

    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 0.0
    fade.toValue = layer.opacity
    fade.duration = reduceMotion ? 0.10 : 0.16
    fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
    layer.add(fade, forKey: "touchbar.entranceFade")

    guard !reduceMotion, layer.bounds.width > 0, layer.bounds.height > 0 else { return }

    let startTransform = centeredScaleTransform(bounds: layer.bounds, scale: 0.96)
    let scale = CABasicAnimation(keyPath: "transform")
    scale.fromValue = NSValue(caTransform3D: startTransform)
    scale.toValue = NSValue(caTransform3D: CATransform3DIdentity)
    scale.duration = 0.16
    scale.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
    layer.add(scale, forKey: "touchbar.entranceScale")
  }

  static func crossfade(_ layer: CALayer?, duration: CFTimeInterval = 0.15) {
    guard let layer = layer else { return }
    let transition = CATransition()
    transition.type = .fade
    transition.duration = reduceMotion ? 0.08 : duration
    transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
    layer.add(transition, forKey: "touchbar.contentCrossfade")
  }
}

/// Dark translucent glass surface built exclusively with static CALayers (zero shaders, 0% idle CPU).
final class GlassSurfaceLayer: CALayer {
  private let innerGlowLayer = CAGradientLayer()
  private let rimGradientLayer = CAGradientLayer()
  private let rimMaskLayer = CAShapeLayer()

  var tintColor: NSColor? {
    didSet { updateAppearance(animated: true) }
  }

  var isActive: Bool = false {
    didSet {
      if oldValue != isActive {
        updateAppearance(animated: true)
      }
    }
  }

  var isPressed: Bool = false {
    didSet {
      if oldValue != isPressed {
        updateAppearance(animated: true)
      }
    }
  }

  var isControlEnabled: Bool = true {
    didSet {
      if oldValue != isControlEnabled {
        updateAppearance(animated: true)
      }
    }
  }

  var isSubtle: Bool = false {
    didSet {
      if oldValue != isSubtle {
        updateAppearance(animated: false)
      }
    }
  }

  override init() {
    super.init()
    commonInit()
  }

  override init(layer: Any) {
    super.init(layer: layer)
    if let other = layer as? GlassSurfaceLayer {
      self.tintColor = other.tintColor
      self.isActive = other.isActive
      self.isPressed = other.isPressed
      self.isControlEnabled = other.isControlEnabled
      self.isSubtle = other.isSubtle
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func commonInit() {
    cornerRadius = 7.0
    cornerCurve = .continuous
    masksToBounds = true

    innerGlowLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
    innerGlowLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
    innerGlowLayer.locations = [0.0, 0.45, 1.0]
    addSublayer(innerGlowLayer)

    rimGradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
    rimGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
    rimGradientLayer.locations = [0.0, 0.5, 1.0]

    rimMaskLayer.fillColor = nil
    rimMaskLayer.strokeColor = NSColor.white.cgColor
    rimMaskLayer.lineWidth = 1.0
    rimGradientLayer.mask = rimMaskLayer
    addSublayer(rimGradientLayer)

    updateAppearance(animated: false)
  }

  override func layoutSublayers() {
    super.layoutSublayers()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    innerGlowLayer.frame = bounds
    rimGradientLayer.frame = bounds
    let insetRect = bounds.insetBy(dx: 0.5, dy: 0.5)
    if insetRect.width > 0, insetRect.height > 0 {
      let radius = max(0, min(cornerRadius - 0.5, min(insetRect.width, insetRect.height) / 2))
      rimMaskLayer.path = CGPath(
        roundedRect: insetRect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    } else {
      rimMaskLayer.path = nil
    }
    CATransaction.commit()
  }

  func updateAppearance(animated: Bool) {
    let fillColor: CGColor
    let glowTopAlpha: CGFloat
    let rimTopAlpha: CGFloat
    let rimMidAlpha: CGFloat
    let rimBotAlpha: CGFloat

    if let tint = tintColor {
      let fillAlpha: CGFloat = isPressed ? 0.88 : (isActive ? 0.78 : 0.64)
      fillColor = tint.withAlphaComponent(fillAlpha).cgColor
      glowTopAlpha = isPressed ? 0.30 : 0.20
      rimTopAlpha = isPressed ? 0.68 : 0.52
      rimMidAlpha = 0.24
      rimBotAlpha = 0.10
    } else if isSubtle {
      let fillAlpha: CGFloat = isPressed ? 0.20 : 0.08
      fillColor = NSColor(white: 1.0, alpha: fillAlpha).cgColor
      glowTopAlpha = isPressed ? 0.14 : 0.06
      rimTopAlpha = isPressed ? 0.36 : 0.18
      rimMidAlpha = 0.08
      rimBotAlpha = 0.04
    } else if isActive {
      let fillAlpha: CGFloat = isPressed ? 0.34 : 0.25
      fillColor = NSColor(white: 1.0, alpha: fillAlpha).cgColor
      glowTopAlpha = isPressed ? 0.28 : 0.20
      rimTopAlpha = isPressed ? 0.68 : 0.54
      rimMidAlpha = 0.24
      rimBotAlpha = 0.10
    } else {
      let fillAlpha: CGFloat = isPressed ? 0.25 : 0.13
      fillColor = NSColor(white: 1.0, alpha: fillAlpha).cgColor
      glowTopAlpha = isPressed ? 0.24 : 0.12
      rimTopAlpha = isPressed ? 0.58 : 0.36
      rimMidAlpha = isPressed ? 0.22 : 0.14
      rimBotAlpha = 0.06
    }

    CATransaction.begin()
    CATransaction.setDisableActions(!animated)
    if animated {
      CATransaction.setAnimationDuration(0.15)
      CATransaction.setAnimationTimingFunction(
        CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
      )
    }

    backgroundColor = fillColor
    opacity = isControlEnabled ? 1.0 : 0.42
    innerGlowLayer.colors = [
      NSColor(white: 1.0, alpha: glowTopAlpha).cgColor,
      NSColor(white: 1.0, alpha: glowTopAlpha * 0.2).cgColor,
      NSColor(white: 1.0, alpha: 0.0).cgColor,
    ]
    rimGradientLayer.colors = [
      NSColor(white: 1.0, alpha: rimTopAlpha).cgColor,
      NSColor(white: 1.0, alpha: rimMidAlpha).cgColor,
      NSColor(white: 1.0, alpha: rimBotAlpha).cgColor,
    ]

    CATransaction.commit()
  }
}
