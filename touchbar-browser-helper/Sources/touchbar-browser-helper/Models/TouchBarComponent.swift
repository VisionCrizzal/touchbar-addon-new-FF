//
//  TouchBarComponent.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 08/11/2020.
//

import Cocoa
import QuartzCore

@MainActor
final class FaviconCache {
  private static let cache: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 120
    return cache
  }()

  static func image(forBase64 base64: String) -> NSImage? {
    guard !base64.isEmpty else { return nil }
    let key = base64 as NSString
    if let cached = cache.object(forKey: key) {
      return cached
    }

    guard let data = Data(base64Encoded: base64),
          let image = NSImage(data: data) else {
      return nil
    }

    image.size = NSSize(width: 16, height: 16)
    cache.setObject(image, forKey: key)
    return image
  }
}

@MainActor
func resolveTouchBarImage(
  symbol: String?,
  icon: String?,
  accessibilityDescription: String? = nil,
  pointSize: CGFloat = 13.5
) -> NSImage? {
  if let symbol = symbol, !symbol.isEmpty {
    if let base = NSImage(
      systemSymbolName: symbol,
      accessibilityDescription: accessibilityDescription ?? symbol
    ) {
      let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
      return base.withSymbolConfiguration(config) ?? base
    }
  }

  if let icon = icon, !icon.isEmpty {
    return NSImage(named: icon)
  }

  return nil
}

@MainActor
final class TabScrubberItemView: NSScrubberItemView {
  private let glassLayer = GlassSurfaceLayer()
  private let faviconView = NSImageView()
  private let label = NSTextField(labelWithString: "")
  private let badgeView = NSImageView()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.cornerRadius = 7
    layer?.cornerCurve = .continuous

    glassLayer.isSubtle = true
    layer?.insertSublayer(glassLayer, at: 0)

    faviconView.imageScaling = .scaleProportionallyDown
    faviconView.setContentHuggingPriority(.required, for: .horizontal)
    faviconView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      faviconView.widthAnchor.constraint(equalToConstant: 16),
      faviconView.heightAnchor.constraint(equalToConstant: 16),
    ])

    label.lineBreakMode = .byTruncatingTail
    label.maximumNumberOfLines = 1
    label.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
    label.textColor = .white
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    badgeView.imageScaling = .scaleProportionallyDown
    badgeView.setContentHuggingPriority(.required, for: .horizontal)
    badgeView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      badgeView.widthAnchor.constraint(equalToConstant: 12),
      badgeView.heightAnchor.constraint(equalToConstant: 12),
    ])

    let stack = NSStackView(views: [faviconView, label, badgeView])
    stack.orientation = .horizontal
    stack.spacing = 5
    stack.alignment = .centerY
    stack.detachesHiddenViews = true
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    stack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    faviconView.image = nil
    faviconView.contentTintColor = nil
    label.stringValue = ""
    label.isHidden = false
    badgeView.image = nil
    badgeView.isHidden = true
    alphaValue = 1.0
    isHidden = false
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    glassLayer.frame = bounds
    CATransaction.commit()
  }

  func configure(item: ScrubberItemSpec, showTitle: Bool, glassStyle: Bool) {
    if let faviconBase64 = item.favicon,
       let favImage = FaviconCache.image(forBase64: faviconBase64) {
      faviconView.image = favImage
      faviconView.contentTintColor = nil
    } else {
      faviconView.image = resolveTouchBarImage(
        symbol: "globe",
        icon: nil,
        accessibilityDescription: item.label,
        pointSize: 13
      )
      faviconView.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
    }

    if showTitle {
      label.stringValue = item.label
      label.isHidden = false
    } else {
      label.stringValue = ""
      label.isHidden = true
    }

    if let symbol = item.symbol, !symbol.isEmpty,
       let badgeImg = resolveTouchBarImage(
         symbol: symbol,
         icon: nil,
         accessibilityDescription: item.label,
         pointSize: 11
       ) {
      badgeView.image = badgeImg
      badgeView.isHidden = false
      switch symbol {
      case "speaker.wave.2.fill":
        badgeView.contentTintColor = NSColor.systemGreen
      case "speaker.slash.fill":
        badgeView.contentTintColor = NSColor.systemRed
      default:
        badgeView.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
      }
    } else {
      badgeView.image = nil
      badgeView.isHidden = true
    }

    let isActive = item.active == true
    if glassStyle {
      // Active item highlights via GlassScrubberSelectionView sliding underneath.
      glassLayer.isHidden = isActive
      glassLayer.isSubtle = true
      layer?.backgroundColor = nil
      layer?.borderWidth = 0.0
      layer?.borderColor = nil
    } else {
      glassLayer.isHidden = true
      layer?.backgroundColor = NSColor(white: 1.0, alpha: isActive ? 0.24 : 0.10).cgColor
      if isActive {
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.35).cgColor
      } else {
        layer?.borderWidth = 0.0
        layer?.borderColor = nil
      }
    }

    label.font = NSFont.systemFont(ofSize: 12.5, weight: isActive ? .semibold : .regular)
    needsLayout = true
  }
}

@MainActor
final class ScrubberTouchBarController:
  NSObject,
  NSScrubberDataSource,
  NSScrubberDelegate,
  @MainActor NSScrubberFlowLayoutDelegate
{
  private static let itemIdentifier = NSUserInterfaceItemIdentifier("TabScrubberItem")

  let name: String
  private var items: [ScrubberItemSpec]
  private let glassStyle: Bool
  private let browserCommunication: BrowserCommunication
  private var isUpdatingSelection = false
  let scrubber: NSScrubber

  init(
    name: String,
    items: [ScrubberItemSpec],
    selectedIndex: Int?,
    glassStyle: Bool,
    browserCommunication: BrowserCommunication
  ) {
    self.name = name
    self.items = items
    self.glassStyle = glassStyle
    self.browserCommunication = browserCommunication

    let scrubber = NSScrubber()
    let layout = NSScrubberFlowLayout()
    layout.itemSpacing = 6
    scrubber.scrubberLayout = layout
    scrubber.mode = .free
    scrubber.selectionBackgroundStyle = glassStyle ? GlassScrubberSelectionStyle() : .roundedBackground
    scrubber.showsAdditionalContentIndicators = true
    scrubber.register(TabScrubberItemView.self, forItemIdentifier: Self.itemIdentifier)
    scrubber.setContentHuggingPriority(.defaultLow, for: .horizontal)
    scrubber.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    self.scrubber = scrubber

    super.init()

    scrubber.dataSource = self
    scrubber.delegate = self

    applySelection(selectedIndex, animated: false)
  }

  func update(items: [ScrubberItemSpec]?, selectedIndex: Int?, animated: Bool = true) {
    isUpdatingSelection = true
    defer { isUpdatingSelection = false }

    guard let newItems = items else {
      applySelection(selectedIndex, animated: animated)
      return
    }

    let oldIds = self.items.map(\.id)
    let newIds = newItems.map(\.id)

    if oldIds == newIds {
      var changedIndices = IndexSet()
      for idx in 0..<newItems.count where self.items[idx] != newItems[idx] {
        changedIndices.insert(idx)
      }
      self.items = newItems

      // Reconfigure visible item views in place instead of calling NSScrubber.reloadItems(at:).
      // AppKit's reloadItems(at:) removes the outgoing view from _itemViewMap while keeping it in
      // _contentView.subviews during its async crossfade; a subsequent reloadData() before that
      // transition finishes drops the exiting view permanently as an overlapping ghost label.
      for idx in changedIndices {
        if let itemView = scrubber.itemViewForItem(at: idx) as? TabScrubberItemView {
          itemView.configure(
            item: newItems[idx],
            showTitle: shouldShowTitle(for: idx),
            glassStyle: glassStyle
          )
        }
      }

      if animated && !TouchBarMotion.reduceMotion {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.22
          context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
          context.allowsImplicitAnimation = true
          invalidateLayout(for: changedIndices)
          if let idx = selectedIndex, idx >= 0, idx < newItems.count {
            scrubber.animator().selectedIndex = idx
            scrubber.animator().scrollItem(at: idx, to: .center)
          } else {
            scrubber.selectedIndex = -1
          }
        }
      } else {
        invalidateLayout(for: changedIndices)
        applySelection(selectedIndex, animated: false)
      }
    } else {
      self.items = newItems
      scrubber.reloadData()
      applySelection(selectedIndex, animated: false)
    }
  }

  private func invalidateLayout(for changedIndices: IndexSet) {
    guard !changedIndices.isEmpty else { return }
    if let flowLayout = scrubber.scrubberLayout as? NSScrubberFlowLayout {
      flowLayout.invalidateLayoutForItems(at: changedIndices)
    } else {
      scrubber.scrubberLayout.invalidateLayout()
    }
  }

  private func shouldShowTitle(for index: Int) -> Bool {
    guard index >= 0 && index < items.count else { return false }
    return items.count <= 4 || items[index].active == true
  }

  private func applySelection(_ selectedIndex: Int?, animated: Bool) {
    isUpdatingSelection = true
    defer { isUpdatingSelection = false }

    if let idx = selectedIndex, idx >= 0, idx < items.count {
      if animated && !TouchBarMotion.reduceMotion {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.22
          context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1.0, 0.32, 1.0)
          context.allowsImplicitAnimation = true
          scrubber.animator().selectedIndex = idx
          scrubber.animator().scrollItem(at: idx, to: .center)
        }
      } else {
        scrubber.selectedIndex = idx
        scrubber.scrollItem(at: idx, to: .center)
      }
    } else {
      scrubber.selectedIndex = -1
    }
  }

  func numberOfItems(for scrubber: NSScrubber) -> Int {
    items.count
  }

  func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
    let view =
      scrubber.makeItem(withIdentifier: Self.itemIdentifier, owner: nil) as? TabScrubberItemView
      ?? TabScrubberItemView()

    if index >= 0 && index < items.count {
      view.configure(
        item: items[index],
        showTitle: shouldShowTitle(for: index),
        glassStyle: glassStyle
      )
    }
    return view
  }

  func scrubber(
    _ scrubber: NSScrubber,
    layout: NSScrubberFlowLayout,
    sizeForItemAt itemIndex: Int
  ) -> NSSize {
    guard itemIndex >= 0 && itemIndex < items.count else {
      return NSSize(width: 80, height: 30)
    }

    let item = items[itemIndex]
    let hasBadge = item.symbol?.isEmpty == false

    if !shouldShowTitle(for: itemIndex) {
      return NSSize(width: hasBadge ? 54 : 42, height: 30)
    }

    let font = NSFont.systemFont(ofSize: 12.5, weight: item.active == true ? .semibold : .regular)
    let textWidth = (item.label as NSString).size(withAttributes: [.font: font]).width
    let extraWidth: CGFloat = 16 + 16 + 5 + (hasBadge ? 16 : 0)
    let width = min(max(ceil(textWidth) + extraWidth, 84), 135)
    return NSSize(width: width, height: 30)
  }

  func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
    guard !isUpdatingSelection, selectedIndex >= 0, selectedIndex < items.count else {
      return
    }

    let item = items[selectedIndex]
    NSLog("Scrubber action: %@ index=%d id=%@", name, selectedIndex, item.id)
    browserCommunication.sendMessage(
      ScrubberActionMessage(name: name, index: selectedIndex, itemId: item.id)
    )
  }
}

@MainActor
final class PopoverBarDelegate: NSObject, NSTouchBarDelegate {
  private let children: [TouchBarComponent]

  init(children: [TouchBarComponent]) {
    self.children = children
    super.init()
  }

  func touchBar(
    _ touchBar: NSTouchBar,
    makeItemForIdentifier identifier: NSTouchBarItem.Identifier
  ) -> NSTouchBarItem? {
    children.first(where: { $0.identifier == identifier })?.touchBarItem
  }
}

@MainActor
final class TouchBarComponent: NSObject {
  enum SpacerSize: Equatable {
    case small
    case large
    case flexible

    static func from(_ raw: String?) -> SpacerSize {
      switch raw {
      case "large":
        return .large
      case "flexible":
        return .flexible
      default:
        return .small
      }
    }
  }

  enum Component {
    case button(
      label: String,
      icon: String?,
      symbol: String?,
      bezelColor: NSColor?,
      enabled: Bool,
      width: CGFloat?
    )
    case slider(label: String?, value: Double, color: NSColor?)
    case label(text: String, color: NSColor?)
    case spacer(size: SpacerSize)
    case scrubber(items: [ScrubberItemSpec], selectedIndex: Int?)
    case popover(
      label: String,
      icon: String?,
      symbol: String?,
      bezelColor: NSColor?,
      children: [TouchBarComponent]
    )
    case segmented(segments: [SegmentSpec])
  }

  let name: String
  let identifier: NSTouchBarItem.Identifier
  let glassStyle: Bool
  private(set) var component: Component
  private let browserCommunication: BrowserCommunication
  private let originalWidth: CGFloat?

  var scrubberController: ScrubberTouchBarController?
  private var popoverDelegate: PopoverBarDelegate?
  private var glassButton: GlassTouchBarButton?
  private var glassSegmented: GlassSegmentedView?
  private var glassSlider: GlassSliderView?

  var primaryView: NSView? {
    touchBarItem.view
  }

  init(
    name: String,
    component: Component,
    glassStyle: Bool = true,
    browserCommunication: BrowserCommunication
  ) {
    self.name = name
    self.component = component
    self.glassStyle = glassStyle
    self.browserCommunication = browserCommunication

    if case .button(_, _, _, _, _, let width) = component {
      self.originalWidth = width
    } else {
      self.originalWidth = nil
    }

    switch component {
    case .spacer(let size):
      switch size {
      case .small:
        self.identifier = .fixedSpaceSmall
      case .large:
        self.identifier = .fixedSpaceLarge
      case .flexible:
        self.identifier = .flexibleSpace
      }
    default:
      let shortID = String(UUID().uuidString.prefix(8))
      self.identifier = .init("\(identifierPrefix).layout-component-\(shortID)")
    }

    super.init()
  }

  lazy var touchBarItem: NSTouchBarItem = {
    switch component {
    case .button(let label, let iconName, let symbolName, let bezelColor, let enabled, let width):
      let image = resolveTouchBarImage(
        symbol: symbolName,
        icon: iconName,
        accessibilityDescription: label.isEmpty ? name : label
      )

      let effectiveWidth: CGFloat? = width ?? ((label.isEmpty && image != nil) ? 38.0 : nil)

      if glassStyle {
        let customItem = NSCustomTouchBarItem(identifier: identifier)
        let button = GlassTouchBarButton(
          label: label,
          image: image,
          bezelColor: bezelColor,
          enabled: enabled,
          width: effectiveWidth
        )
        button.onAction = { [weak self] in
          self?.triggerButtonAction()
        }
        self.glassButton = button
        customItem.view = button
        return customItem
      }

      if let effectiveWidth = effectiveWidth {
        let customItem = NSCustomTouchBarItem(identifier: identifier)
        let btn: NSButton
        if let image = image, !label.isEmpty {
          btn = NSButton(title: label, image: image, target: self, action: #selector(buttonAction(_:)))
        } else if let image = image {
          btn = NSButton(image: image, target: self, action: #selector(buttonAction(_:)))
        } else {
          btn = NSButton(title: label, target: self, action: #selector(buttonAction(_:)))
        }
        btn.bezelStyle = .rounded
        btn.bezelColor = bezelColor
        btn.isEnabled = enabled
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          btn.widthAnchor.constraint(equalToConstant: effectiveWidth),
          btn.heightAnchor.constraint(equalToConstant: 30),
        ])
        customItem.view = btn
        return customItem
      }

      let buttonItem: NSButtonTouchBarItem
      if let image = image, !label.isEmpty {
        buttonItem = NSButtonTouchBarItem(
          identifier: identifier,
          title: label,
          image: image,
          target: self,
          action: #selector(buttonAction(_:))
        )
      } else if let image = image {
        buttonItem = NSButtonTouchBarItem(
          identifier: identifier,
          image: image,
          target: self,
          action: #selector(buttonAction(_:))
        )
      } else {
        buttonItem = NSButtonTouchBarItem(
          identifier: identifier,
          title: label,
          target: self,
          action: #selector(buttonAction(_:))
        )
      }

      buttonItem.bezelColor = bezelColor
      buttonItem.isEnabled = enabled
      return buttonItem

    case .slider(let label, let value, let color):
      if glassStyle {
        let customItem = NSCustomTouchBarItem(identifier: identifier)
        let sliderView = GlassSliderView(
          label: label,
          value: value,
          color: color
        )
        sliderView.onValueCommitted = { [weak self] newValue in
          self?.triggerSliderAction(value: newValue)
        }
        self.glassSlider = sliderView
        customItem.view = sliderView
        return customItem
      }

      let sliderItem = NSSliderTouchBarItem(identifier: identifier)
      sliderItem.target = self
      sliderItem.action = #selector(sliderAction(_:))
      sliderItem.label = label

      let slider = sliderItem.slider
      slider.minValue = 0.0
      slider.maxValue = 1.0
      slider.isContinuous = false
      slider.doubleValue = value.isFinite ? min(max(value, 0.0), 1.0) : 0.0
      slider.trackFillColor = color
      slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
      let minWidth = slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
      minWidth.priority = .defaultHigh
      minWidth.isActive = true
      return sliderItem

    case .label(let text, let color):
      let customItem = NSCustomTouchBarItem(identifier: identifier)
      let textField = NSTextField(labelWithString: text)
      textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
      textField.textColor = color ?? .labelColor
      textField.lineBreakMode = .byTruncatingTail
      customItem.view = textField
      return customItem

    case .spacer:
      return NSCustomTouchBarItem(identifier: identifier)

    case .scrubber(let items, let selectedIndex):
      let controller = ScrubberTouchBarController(
        name: name,
        items: items,
        selectedIndex: selectedIndex,
        glassStyle: glassStyle,
        browserCommunication: browserCommunication
      )
      self.scrubberController = controller

      let customItem = NSCustomTouchBarItem(identifier: identifier)
      customItem.view = controller.scrubber
      return customItem

    case .popover(let label, let iconName, let symbolName, let bezelColor, let children):
      let popoverItem = NSPopoverTouchBarItem(identifier: identifier)
      popoverItem.collapsedRepresentationLabel = label
      popoverItem.collapsedRepresentationImage = resolveTouchBarImage(
        symbol: symbolName,
        icon: iconName,
        accessibilityDescription: label.isEmpty ? name : label
      )
      popoverItem.showsCloseButton = true

      if let bezelColor = bezelColor, let button = popoverItem.collapsedRepresentation as? NSButton {
        button.bezelColor = bezelColor
      }

      let childBar = NSTouchBar()
      childBar.defaultItemIdentifiers = children.map { $0.identifier }
      let delegate = PopoverBarDelegate(children: children)
      childBar.delegate = delegate
      self.popoverDelegate = delegate
      popoverItem.popoverTouchBar = childBar
      return popoverItem

    case .segmented(let segments):
      let customItem = NSCustomTouchBarItem(identifier: identifier)
      if glassStyle {
        let segView = GlassSegmentedView(segments: segments)
        segView.onSelectSegment = { [weak self] idx in
          self?.triggerSegmentedAction(at: idx)
        }
        self.glassSegmented = segView
        customItem.view = segView
        return customItem
      }

      let seg = NSSegmentedControl()
      seg.segmentCount = segments.count
      seg.trackingMode = .momentary
      seg.target = self
      seg.action = #selector(segmentedAction(_:))
      seg.translatesAutoresizingMaskIntoConstraints = false
      seg.heightAnchor.constraint(equalToConstant: 30).isActive = true

      for (idx, spec) in segments.enumerated() {
        if let img = resolveTouchBarImage(
          symbol: spec.symbol,
          icon: spec.icon,
          accessibilityDescription: spec.label ?? spec.name
        ) {
          seg.setImage(img, forSegment: idx)
        }
        if let lbl = spec.label, !lbl.isEmpty {
          seg.setLabel(lbl, forSegment: idx)
        }
        seg.setEnabled(spec.enabled ?? true, forSegment: idx)
        seg.setWidth(CGFloat(spec.width ?? 34), forSegment: idx)
      }

      customItem.view = seg
      return customItem
    }
  }()

  func matchesStructure(of spec: ComponentSpec) -> Bool {
    guard spec.name == name, let type = spec.type else {
      return false
    }

    switch component {
    case .button:
      let specWidth = spec.width.map { CGFloat($0) }
      return type == "button" && specWidth == originalWidth
    case .segmented(let existingSegments):
      guard type == "segmented" else { return false }
      return existingSegments.map(\.name) == (spec.segments ?? []).map(\.name)
    case .slider:
      return type == "slider"
    case .label:
      return type == "label"
    case .scrubber:
      return type == "scrubber"
    case .spacer(let size):
      return type == "spacer" && SpacerSize.from(spec.size) == size
    case .popover:
      return false
    }
  }

  func applySpecInPlace(_ spec: ComponentSpec, animated: Bool) {
    switch component {
    case .button:
      let label = spec.label ?? ""
      let bezelColor = (spec.bezelColor ?? spec.color).flatMap { NSColor.from(hex: $0) }
      let enabled = spec.enabled ?? true
      let width = spec.width.map { CGFloat($0) }
      component = .button(
        label: label,
        icon: spec.icon,
        symbol: spec.symbol,
        bezelColor: bezelColor,
        enabled: enabled,
        width: width
      )
      let image = resolveTouchBarImage(
        symbol: spec.symbol,
        icon: spec.icon,
        accessibilityDescription: label.isEmpty ? name : label
      )
      if let glassButton = glassButton {
        glassButton.configure(
          label: label,
          image: image,
          bezelColor: bezelColor,
          enabled: enabled,
          animated: animated
        )
      } else if let buttonItem = touchBarItem as? NSButtonTouchBarItem {
        buttonItem.title = label
        buttonItem.image = image
        buttonItem.bezelColor = bezelColor
        buttonItem.isEnabled = enabled
      } else if let customItem = touchBarItem as? NSCustomTouchBarItem,
                let button = customItem.view as? NSButton {
        button.title = label
        button.image = image
        button.bezelColor = bezelColor
        button.isEnabled = enabled
      }

    case .segmented:
      let segments = spec.segments ?? []
      component = .segmented(segments: segments)
      if let glassSegmented = glassSegmented {
        glassSegmented.update(segments: segments, animated: animated)
      } else if let customItem = touchBarItem as? NSCustomTouchBarItem,
                let seg = customItem.view as? NSSegmentedControl {
        for (idx, segSpec) in segments.enumerated() where idx < seg.segmentCount {
          let img = resolveTouchBarImage(
            symbol: segSpec.symbol,
            icon: segSpec.icon,
            accessibilityDescription: segSpec.label ?? segSpec.name
          )
          seg.setImage(img, forSegment: idx)
          seg.setLabel(segSpec.label ?? "", forSegment: idx)
          seg.setEnabled(segSpec.enabled ?? true, forSegment: idx)
        }
      }

    case .slider:
      let value = (spec.value?.isFinite == true) ? (spec.value ?? 0.0) : 0.0
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      component = .slider(label: spec.label, value: value, color: color)
      if let glassSlider = glassSlider {
        glassSlider.update(label: spec.label, value: value, color: color, resetColorIfNil: true)
      } else if let sliderItem = touchBarItem as? NSSliderTouchBarItem {
        sliderItem.label = spec.label
        sliderItem.slider.doubleValue = min(max(value, 0.0), 1.0)
        sliderItem.slider.trackFillColor = color
      }

    case .label:
      let text = spec.label ?? ""
      let color = spec.color.flatMap { NSColor.from(hex: $0) }
      component = .label(text: text, color: color)
      if let customItem = touchBarItem as? NSCustomTouchBarItem,
         let textField = customItem.view as? NSTextField {
        textField.stringValue = text
        textField.textColor = color ?? .labelColor
      }

    case .scrubber:
      let items = spec.items ?? []
      component = .scrubber(items: items, selectedIndex: spec.selectedIndex)
      _ = touchBarItem
      scrubberController?.update(items: items, selectedIndex: spec.selectedIndex, animated: animated)

    case .spacer, .popover:
      break
    }
  }

  func applyUpdateValues(_ values: ComponentUpdateValues) {
    switch component {
    case .button(let oldLabel, let oldIcon, let oldSymbol, let oldBezelColor, let oldEnabled, let width):
      let bezelHex = values.bezelColor ?? values.color
      let updatedLabel = values.label ?? oldLabel
      let updatedSymbol = values.symbol ?? oldSymbol
      let updatedIcon = values.icon ?? oldIcon
      let updatedBezelColor: NSColor? = bezelHex.map { $0.isEmpty ? nil : NSColor.from(hex: $0) } ?? oldBezelColor
      let updatedEnabled = values.enabled ?? oldEnabled

      component = .button(
        label: updatedLabel,
        icon: updatedIcon,
        symbol: updatedSymbol,
        bezelColor: updatedBezelColor,
        enabled: updatedEnabled,
        width: width
      )

      let resolvedImage =
        (values.symbol != nil || values.icon != nil)
        ? resolveTouchBarImage(
          symbol: updatedSymbol,
          icon: updatedIcon,
          accessibilityDescription: updatedLabel.isEmpty ? name : updatedLabel
        )
        : nil

      if let glassButton = glassButton {
        let finalImage = resolvedImage ?? resolveTouchBarImage(
          symbol: updatedSymbol,
          icon: updatedIcon,
          accessibilityDescription: updatedLabel.isEmpty ? name : updatedLabel
        )
        glassButton.configure(
          label: updatedLabel,
          image: finalImage,
          bezelColor: updatedBezelColor,
          enabled: updatedEnabled,
          animated: true
        )
      } else if let buttonItem = touchBarItem as? NSButtonTouchBarItem {
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
      } else if let customItem = touchBarItem as? NSCustomTouchBarItem,
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
      let newColor = values.color.flatMap { NSColor.from(hex: $0) }
      if let glassSlider = glassSlider {
        glassSlider.update(label: values.label, value: values.value, color: newColor)
      } else if let slider = touchBarItem as? NSSliderTouchBarItem {
        if let newValue = values.value, newValue.isFinite {
          slider.slider.doubleValue = min(max(newValue, 0.0), 1.0)
        }
        if let newLabel = values.label {
          slider.label = newLabel
        }
        if let newColor = newColor {
          slider.slider.trackFillColor = newColor
        }
      }

    case .label:
      guard let customItem = touchBarItem as? NSCustomTouchBarItem,
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
        _ = touchBarItem
        scrubberController?.update(
          items: values.items,
          selectedIndex: values.selectedIndex,
          animated: true
        )
      }

    case .spacer, .popover, .segmented:
      break
    }
  }

  private func triggerButtonAction() {
    guard case .button = component else { return }
    NSLog("Button action: %@", name)
    browserCommunication.sendMessage(ButtonActionMessage(name: name))
  }

  private func triggerSegmentedAction(at idx: Int) {
    guard case .segmented(let segments) = component else { return }
    guard idx >= 0 && idx < segments.count else { return }
    let targetName = segments[idx].name
    NSLog("Segmented action: %@", targetName)
    browserCommunication.sendMessage(ButtonActionMessage(name: targetName))
  }

  @objc func buttonAction(_ sender: Any?) {
    triggerButtonAction()
  }

  @objc func segmentedAction(_ sender: NSSegmentedControl) {
    triggerSegmentedAction(at: sender.selectedSegment)
  }

  private func triggerSliderAction(value: Double) {
    NSLog("Slider action: %@ value=%.4f", name, value)
    browserCommunication.sendMessage(
      SliderActionMessage(name: name, value: value)
    )
  }

  @objc func sliderAction(_ sender: NSSliderTouchBarItem) {
    triggerSliderAction(value: sender.slider.doubleValue)
  }
}
