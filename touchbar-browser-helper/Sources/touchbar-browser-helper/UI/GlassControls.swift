//
//  GlassControls.swift
//  touchbar-browser-helper
//

import Cocoa
import QuartzCore

/// Custom Dark Glass Touch Bar button with interruptible spring press feedback and smooth content crossfade.
@MainActor
final class GlassTouchBarButton: NSView {
  private let surfaceLayer = GlassSurfaceLayer()
  private let stackView = NSStackView()
  private let iconView = NSImageView()
  private let titleLabel = NSTextField(labelWithString: "")
  private var activeTouchIdentity: (any NSObjectProtocol & NSCopying)?

  var isEnabled: Bool = true {
    didSet {
      surfaceLayer.isControlEnabled = isEnabled
      iconView.alphaValue = isEnabled ? 1.0 : 0.5
      titleLabel.alphaValue = isEnabled ? 1.0 : 0.5
    }
  }

  var onAction: (() -> Void)?

  init(
    label: String,
    image: NSImage?,
    bezelColor: NSColor?,
    enabled: Bool,
    width: CGFloat?
  ) {
    super.init(frame: NSRect(x: 0, y: 0, width: width ?? 56, height: 30))
    wantsLayer = true
    allowedTouchTypes = [.direct]
    translatesAutoresizingMaskIntoConstraints = false

    layer?.masksToBounds = false
    layer?.addSublayer(surfaceLayer)

    iconView.imageScaling = .scaleProportionallyDown
    iconView.contentTintColor = .white
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    iconView.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    titleLabel.textColor = .white
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.maximumNumberOfLines = 1
    titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

    stackView.orientation = .horizontal
    stackView.alignment = .centerY
    stackView.spacing = 5
    stackView.detachesHiddenViews = true
    stackView.edgeInsets = NSEdgeInsets(
      top: 0,
      left: width == nil ? 10 : 4,
      bottom: 0,
      right: width == nil ? 10 : 4
    )
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.addArrangedSubview(iconView)
    stackView.addArrangedSubview(titleLabel)
    addSubview(stackView)

    var constraints: [NSLayoutConstraint] = [
      heightAnchor.constraint(equalToConstant: 30),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
      stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
    ]

    if let width = width {
      constraints.append(widthAnchor.constraint(equalToConstant: width))
    } else {
      constraints.append(widthAnchor.constraint(greaterThanOrEqualToConstant: 44))
    }

    NSLayoutConstraint.activate(constraints)

    configure(
      label: label,
      image: image,
      bezelColor: bezelColor,
      enabled: enabled,
      animated: false
    )
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    surfaceLayer.frame = bounds
    CATransaction.commit()
  }

  func configure(
    label: String,
    image: NSImage?,
    bezelColor: NSColor?,
    enabled: Bool,
    animated: Bool
  ) {
    let contentChanged = titleLabel.stringValue != label || iconView.image !== image
    if animated && contentChanged {
      TouchBarMotion.crossfade(stackView.layer)
    }

    iconView.image = image
    iconView.isHidden = (image == nil)

    titleLabel.stringValue = label
    titleLabel.isHidden = label.isEmpty

    surfaceLayer.tintColor = bezelColor
    self.isEnabled = enabled
    if !animated {
      surfaceLayer.updateAppearance(animated: false)
    }
  }

  private func setPressed(_ pressed: Bool) {
    guard surfaceLayer.isPressed != pressed else { return }
    surfaceLayer.isPressed = pressed
    TouchBarMotion.animateScale(surfaceLayer, to: pressed ? 1.045 : 1.0)
  }

  override func touchesBegan(with event: NSEvent) {
    guard isEnabled else { return }
    if activeTouchIdentity != nil { return }
    guard let touch = event.touches(matching: .began, in: self).first else { return }
    activeTouchIdentity = touch.identity
    setPressed(true)
  }

  override func touchesMoved(with event: NSEvent) {
    guard let identity = activeTouchIdentity else { return }
    guard let touch = event.touches(matching: .moved, in: self).first(where: { $0.identity.isEqual(identity) }) else {
      return
    }
    let pt = touch.location(in: self)
    setPressed(bounds.insetBy(dx: -8, dy: -8).contains(pt))
  }

  override func touchesEnded(with event: NSEvent) {
    guard let identity = activeTouchIdentity else { return }
    guard let touch = event.touches(matching: .ended, in: self).first(where: { $0.identity.isEqual(identity) }) else {
      return
    }
    activeTouchIdentity = nil
    let pt = touch.location(in: self)
    let inside = bounds.insetBy(dx: -8, dy: -8).contains(pt)
    setPressed(false)
    if inside && isEnabled {
      onAction?()
    }
  }

  override func touchesCancelled(with event: NSEvent) {
    activeTouchIdentity = nil
    setPressed(false)
  }

  override func mouseDown(with event: NSEvent) {
    guard isEnabled else { return }
    setPressed(true)
  }

  override func mouseUp(with event: NSEvent) {
    let pt = convert(event.locationInWindow, from: nil)
    let inside = bounds.contains(pt)
    setPressed(false)
    if inside && isEnabled {
      onAction?()
    }
  }
}

/// Unified Dark Glass segmented pill (e.g. Back | Forward) with per-segment touch spring highlight.
@MainActor
final class GlassSegmentedView: NSView {
  private struct SegmentSlot {
    let container: NSView
    let highlightLayer: CALayer
    let iconView: NSImageView
    let titleLabel: NSTextField
    var enabled: Bool
  }

  private let surfaceLayer = GlassSurfaceLayer()
  private var slots: [SegmentSlot] = []
  private var dividers: [CALayer] = []
  private var activeTouchIdentity: (any NSObjectProtocol & NSCopying)?
  private var activeSegmentIndex: Int?

  var onSelectSegment: ((Int) -> Void)?

  init(segments: [SegmentSpec]) {
    let totalWidth = segments.reduce(CGFloat(0)) { $0 + CGFloat($1.width ?? 34) }
    super.init(frame: NSRect(x: 0, y: 0, width: max(totalWidth, 40), height: 30))
    wantsLayer = true
    allowedTouchTypes = [.direct]
    translatesAutoresizingMaskIntoConstraints = false

    layer?.masksToBounds = false
    layer?.addSublayer(surfaceLayer)

    let rowStack = NSStackView()
    rowStack.orientation = .horizontal
    rowStack.spacing = 0
    rowStack.alignment = .centerY
    rowStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rowStack)

    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 30),
      rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
      rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
      rowStack.topAnchor.constraint(equalTo: topAnchor),
      rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    for (idx, spec) in segments.enumerated() {
      let slotView = NSView()
      slotView.wantsLayer = true
      slotView.translatesAutoresizingMaskIntoConstraints = false

      let highlight = CALayer()
      highlight.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
      highlight.opacity = 0
      highlight.cornerRadius = 6.0
      highlight.cornerCurve = .continuous
      slotView.layer?.addSublayer(highlight)

      let iconView = NSImageView()
      iconView.imageScaling = .scaleProportionallyDown
      iconView.contentTintColor = .white
      iconView.translatesAutoresizingMaskIntoConstraints = false

      let label = NSTextField(labelWithString: "")
      label.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
      label.textColor = .white
      label.lineBreakMode = .byTruncatingTail

      let innerStack = NSStackView(views: [iconView, label])
      innerStack.orientation = .horizontal
      innerStack.spacing = 4
      innerStack.alignment = .centerY
      innerStack.detachesHiddenViews = true
      innerStack.translatesAutoresizingMaskIntoConstraints = false
      slotView.addSubview(innerStack)

      let segWidth = CGFloat(spec.width ?? 34)
      NSLayoutConstraint.activate([
        slotView.widthAnchor.constraint(equalToConstant: segWidth),
        slotView.heightAnchor.constraint(equalToConstant: 30),
        innerStack.centerXAnchor.constraint(equalTo: slotView.centerXAnchor),
        innerStack.centerYAnchor.constraint(equalTo: slotView.centerYAnchor),
      ])

      rowStack.addArrangedSubview(slotView)
      slots.append(
        SegmentSlot(
          container: slotView,
          highlightLayer: highlight,
          iconView: iconView,
          titleLabel: label,
          enabled: spec.enabled ?? true
        )
      )

      if idx < segments.count - 1 {
        let divider = CALayer()
        divider.backgroundColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        surfaceLayer.addSublayer(divider)
        dividers.append(divider)
      }
    }

    update(segments: segments, animated: false)
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    surfaceLayer.frame = bounds

    for (idx, slot) in slots.enumerated() {
      slot.highlightLayer.frame = slot.container.bounds.insetBy(dx: 2, dy: 2)
      if idx < dividers.count {
        let x = slot.container.frame.maxX
        dividers[idx].frame = CGRect(x: x - 0.5, y: 6, width: 1, height: bounds.height - 12)
      }
    }
    CATransaction.commit()
  }

  func update(segments: [SegmentSpec], animated: Bool) {
    for (idx, spec) in segments.enumerated() where idx < slots.count {
      let image = resolveTouchBarImage(
        symbol: spec.symbol,
        icon: spec.icon,
        accessibilityDescription: spec.label ?? spec.name
      )
      if animated && slots[idx].iconView.image !== image {
        TouchBarMotion.crossfade(slots[idx].container.layer)
      }
      slots[idx].iconView.image = image
      slots[idx].iconView.isHidden = (image == nil)

      let lbl = spec.label ?? ""
      slots[idx].titleLabel.stringValue = lbl
      slots[idx].titleLabel.isHidden = lbl.isEmpty

      let enabled = spec.enabled ?? true
      slots[idx].enabled = enabled
      slots[idx].container.alphaValue = enabled ? 1.0 : 0.42
    }
  }

  private func segmentIndex(at point: CGPoint) -> Int? {
    for (idx, slot) in slots.enumerated() where slot.container.frame.contains(point) {
      return idx
    }
    return nil
  }

  private func setHighlightedSegment(_ targetIndex: Int?) {
    for (idx, slot) in slots.enumerated() {
      let pressed = (idx == targetIndex && slot.enabled)
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.12)
      slot.highlightLayer.opacity = pressed ? 1.0 : 0.0
      CATransaction.commit()
      if let layer = slot.container.layer {
        TouchBarMotion.animateScale(layer, to: pressed ? 1.06 : 1.0)
      }
    }
  }

  override func touchesBegan(with event: NSEvent) {
    if activeTouchIdentity != nil { return }
    guard let touch = event.touches(matching: .began, in: self).first else { return }
    let pt = touch.location(in: self)
    guard let idx = segmentIndex(at: pt), slots[idx].enabled else { return }
    activeTouchIdentity = touch.identity
    activeSegmentIndex = idx
    setHighlightedSegment(idx)
  }

  override func touchesMoved(with event: NSEvent) {
    guard let identity = activeTouchIdentity, let initialIdx = activeSegmentIndex else { return }
    guard let touch = event.touches(matching: .moved, in: self).first(where: { $0.identity.isEqual(identity) }) else {
      return
    }
    let pt = touch.location(in: self)
    let inside = slots[initialIdx].container.frame.insetBy(dx: -4, dy: -8).contains(pt)
    setHighlightedSegment(inside ? initialIdx : nil)
  }

  override func touchesEnded(with event: NSEvent) {
    guard let identity = activeTouchIdentity, let initialIdx = activeSegmentIndex else { return }
    guard let touch = event.touches(matching: .ended, in: self).first(where: { $0.identity.isEqual(identity) }) else {
      return
    }
    activeTouchIdentity = nil
    activeSegmentIndex = nil
    let pt = touch.location(in: self)
    let inside = slots[initialIdx].container.frame.insetBy(dx: -4, dy: -8).contains(pt)
    setHighlightedSegment(nil)
    if inside && slots[initialIdx].enabled {
      onSelectSegment?(initialIdx)
    }
  }

  override func touchesCancelled(with event: NSEvent) {
    activeTouchIdentity = nil
    activeSegmentIndex = nil
    setHighlightedSegment(nil)
  }

  override func mouseDown(with event: NSEvent) {
    let pt = convert(event.locationInWindow, from: nil)
    guard let idx = segmentIndex(at: pt), slots[idx].enabled else { return }
    activeSegmentIndex = idx
    setHighlightedSegment(idx)
  }

  override func mouseUp(with event: NSEvent) {
    guard let initialIdx = activeSegmentIndex else { return }
    activeSegmentIndex = nil
    let pt = convert(event.locationInWindow, from: nil)
    let inside = slots[initialIdx].container.frame.contains(pt)
    setHighlightedSegment(nil)
    if inside && slots[initialIdx].enabled {
      onSelectSegment?(initialIdx)
    }
  }
}

/// Dark Glass active tab selection pill hosted natively by NSScrubber (slides smoothly across tabs).
@MainActor
final class GlassScrubberSelectionView: NSScrubberSelectionView {
  private let surfaceLayer = GlassSurfaceLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    surfaceLayer.isActive = true
    surfaceLayer.updateAppearance(animated: false)
    layer?.addSublayer(surfaceLayer)
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    surfaceLayer.frame = bounds
    CATransaction.commit()
  }
}

final class GlassScrubberSelectionStyle: NSScrubberSelectionStyle {
  override init() {
    super.init()
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func makeSelectionView() -> NSScrubberSelectionView? {
    MainActor.assumeIsolated {
      GlassScrubberSelectionView()
    }
  }
}

/// Dark Glass container for media slider with tabular monospaced timestamp label (zero horizontal jitter).
@MainActor
final class GlassSliderView: NSView {
  private let surfaceLayer = GlassSurfaceLayer()
  private let timestampLabel = NSTextField(labelWithString: "")
  let slider = NSSlider()

  init(label: String?, value: Double, color: NSColor?, target: AnyObject?, action: Selector?) {
    super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 30))
    wantsLayer = true
    translatesAutoresizingMaskIntoConstraints = false

    surfaceLayer.isSubtle = true
    layer?.addSublayer(surfaceLayer)

    timestampLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    timestampLabel.textColor = NSColor(white: 0.92, alpha: 1.0)
    timestampLabel.alignment = .right
    timestampLabel.lineBreakMode = .byClipping
    timestampLabel.setContentHuggingPriority(.required, for: .horizontal)
    timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    timestampLabel.translatesAutoresizingMaskIntoConstraints = false

    slider.minValue = 0.0
    slider.maxValue = 1.0
    slider.isContinuous = false
    slider.doubleValue = value.isFinite ? min(max(value, 0.0), 1.0) : 0.0
    slider.trackFillColor = color
    slider.target = target
    slider.action = action
    slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
    slider.translatesAutoresizingMaskIntoConstraints = false

    let stack = NSStackView(views: [timestampLabel, slider])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    stack.detachesHiddenViews = true
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    let minWidth = widthAnchor.constraint(greaterThanOrEqualToConstant: 230)
    minWidth.priority = .defaultHigh

    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 30),
      minWidth,
      timestampLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    update(label: label, value: value, color: color, resetColorIfNil: true)
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    surfaceLayer.frame = bounds
    CATransaction.commit()
  }

  func update(label: String?, value: Double?, color: NSColor?, resetColorIfNil: Bool = false) {
    if let label = label {
      timestampLabel.stringValue = label
      timestampLabel.isHidden = label.isEmpty
    } else if resetColorIfNil {
      timestampLabel.stringValue = ""
      timestampLabel.isHidden = true
    }

    if let value = value, value.isFinite {
      slider.doubleValue = min(max(value, 0.0), 1.0)
    }

    if let color = color {
      slider.trackFillColor = color
    } else if resetColorIfNil {
      slider.trackFillColor = nil
    }
  }
}
