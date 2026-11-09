import Flutter
import UIKit

final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeTabBar(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

/// Native UITabBar shown by Flutter as a platform view. Liquid Glass, VoiceOver
/// and Reduce Transparency are left to iOS; icons are Phosphor glyphs.
final class NativeTabBar: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    tabBar = UITabBar(frame: frame)
    channel = FlutterMethodChannel(name: "playerszwz/navigation/\(id)", binaryMessenger: messenger)
    super.init()
    tabBar.overrideUserInterfaceStyle = .dark
    tabBar.tintColor = UIColor(red: CGFloat(198) / 255, green: CGFloat(244) / 255, blue: CGFloat(50) / 255, alpha: 1)
    // iOS 26+: leave the bar's appearance to the system so it renders
    // Liquid Glass and adapts to Reduce Transparency / Increase Contrast.
    let args = arguments as? [String: Any] ?? [:]
    let destinations = args["items"] as? [[String: Any]] ?? []
    tabBar.items = destinations.enumerated().map { index, destination in
      let item = UITabBarItem(title: destination["title"] as? String,
                             image: PhosphorGlyph.image(destination, size: 24),
                             selectedImage: PhosphorGlyph.image(destination, prefix: "selected", size: 24))
      item.tag = index
      item.accessibilityIdentifier = "playerszwz.tab.\(index)"
      return item
    }
    tabBar.delegate = self
    select(args["selectedIndex"] as? Int ?? 0)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "select", let index = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.select(index)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func select(_ index: Int) {
    guard let items = tabBar.items, items.indices.contains(index) else { return }
    tabBar.selectedItem = items[index]
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("selected", arguments: item.tag)
  }

  func view() -> UIView { tabBar }
}

private let playersLime = UIColor(red: 198 / 255, green: 244 / 255, blue: 50 / 255, alpha: 1)

// MARK: - Glass button (platform view)

/// Capsule/circle button drawn with the system Liquid Glass material (iOS 26+).
final class GlassButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassButton(frame: frame, id: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

final class GlassButton: NSObject, FlutterPlatformView {
  private let container: UIView
  private let effectView: UIVisualEffectView
  private let stack = UIStackView()
  private let imageView = UIImageView()
  private let label = UILabel()
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    container = UIView(frame: frame)
    effectView = UIVisualEffectView(effect: nil)
    channel = FlutterMethodChannel(name: "playerszwz/glass-button/\(id)", binaryMessenger: messenger)
    super.init()

    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = .dark
    effectView.frame = container.bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    effectView.cornerConfiguration = .capsule()
    container.addSubview(effectView)

    stack.axis = .horizontal
    stack.alignment = .center
    stack.spacing = 6
    stack.isUserInteractionEnabled = false
    stack.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    imageView.setContentHuggingPriority(.required, for: .horizontal)
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    stack.addArrangedSubview(imageView)
    stack.addArrangedSubview(label)
    effectView.contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
    ])

    effectView.isAccessibilityElement = true
    effectView.accessibilityTraits = .button
    effectView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

    apply(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(args)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func apply(_ args: [String: Any]) {
    let prominent = args["prominent"] as? Bool ?? false
    let effect = UIGlassEffect()
    effect.isInteractive = true
    if prominent { effect.tintColor = playersLime }
    effectView.effect = effect

    let foreground: UIColor = prominent ? .black : .white
    let pointSize = CGFloat((args["iconSize"] as? NSNumber)?.doubleValue ?? 17)
    if let image = PhosphorGlyph.image(args, size: pointSize) {
      imageView.image = image
      imageView.isHidden = false
    } else {
      imageView.isHidden = true
    }
    imageView.tintColor = foreground

    let title = args["title"] as? String ?? ""
    label.text = title
    label.textColor = foreground
    label.isHidden = title.isEmpty
    effectView.accessibilityLabel = args["label"] as? String ?? title
  }

  @objc private func tapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    channel.invokeMethod("tap", arguments: nil)
  }

  func view() -> UIView { container }
}

// MARK: - Native sheets (option list, date/time, slider)

/// System sheets presented over Flutter. On iOS 26 partial sheets use dark Liquid Glass.
final class NativeSheets: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "playerszwz/native-sheets", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let host = topController() else {
      result(nil)
      return
    }
    switch call.method {
    case "confirm":
      presentConfirm(args, on: host, result: result)
      return
    case "actions":
      presentActions(args, on: host, result: result)
      return
    case "share":
      presentShare(args, on: host, result: result)
      return
    case "menu":
      presentMenu(args, on: host, result: result)
      return
    default:
      break
    }
    let controller: UIViewController
    switch call.method {
    case "pickOption":
      controller = OptionSheetController(args: args, completion: result)
    case "pickDate":
      controller = DateSheetController(args: args, completion: result)
    default:
      result(FlutterMethodNotImplemented)
      return
    }
    let navigation = UINavigationController(rootViewController: controller)
    navigation.overrideUserInterfaceStyle = .dark
    navigation.view.tintColor = playersLime
    navigation.presentationController?.delegate = controller as? UIAdaptivePresentationControllerDelegate
    if let sheet = navigation.sheetPresentationController {
      sheet.detents = (controller as? SheetSizing)?.detents ?? [.medium()]
      sheet.prefersGrabberVisible = true
    }
    host.present(navigation, animated: true)
  }
}

extension NativeSheets {
  /// iOS 26 alert (Liquid Glass) with a highlighted confirm action.
  fileprivate func presentConfirm(_ args: [String: Any], on host: UIViewController, result: @escaping FlutterResult) {
    let done = OnceResult(result)
    let alert = UIAlertController(title: args["title"] as? String,
                                  message: args["message"] as? String,
                                  preferredStyle: .alert)
    alert.overrideUserInterfaceStyle = .dark
    alert.view.tintColor = playersLime
    alert.addAction(UIAlertAction(title: args["cancel"] as? String ?? "Cancel", style: .cancel) { _ in
      done.finish(false)
    })
    let destructive = args["destructive"] as? Bool ?? true
    let confirm = UIAlertAction(title: args["confirm"] as? String ?? "OK",
                                style: destructive ? .destructive : .default) { _ in
      UINotificationFeedbackGenerator().notificationOccurred(destructive ? .warning : .success)
      done.finish(true)
    }
    alert.addAction(confirm)
    alert.preferredAction = confirm
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    host.present(alert, animated: true)
  }

  /// Action sheet (glass on iOS 26). Returns the tapped index, or nil.
  fileprivate func presentActions(_ args: [String: Any], on host: UIViewController, result: @escaping FlutterResult) {
    let done = OnceResult(result)
    let title = args["title"] as? String
    let sheet = UIAlertController(title: title?.isEmpty == false ? title : nil,
                                  message: args["message"] as? String,
                                  preferredStyle: .actionSheet)
    sheet.overrideUserInterfaceStyle = .dark
    sheet.view.tintColor = .white
    let titles = args["actions"] as? [String] ?? []
    let destructive = args["destructive"] as? [Bool] ?? []
    for (index, text) in titles.enumerated() {
      let isDestructive = index < destructive.count && destructive[index]
      let action = UIAlertAction(title: text, style: isDestructive ? .destructive : .default) { _ in
        done.finish(index)
      }
      sheet.addAction(action)
    }
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done.finish(nil) })
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = host.view
      popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.maxY - 80, width: 1, height: 1)
    }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    host.present(sheet, animated: true)
  }

  fileprivate func presentShare(_ args: [String: Any], on host: UIViewController, result: @escaping FlutterResult) {
    var items: [Any] = []
    if let text = args["text"] as? String, !text.isEmpty { items.append(text) }
    if let link = args["url"] as? String, let url = URL(string: link) { items.append(url) }
    let share = UIActivityViewController(activityItems: items, applicationActivities: nil)
    share.overrideUserInterfaceStyle = .dark
    if let popover = share.popoverPresentationController {
      popover.sourceView = host.view
      popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 1, height: 1)
    }
    share.completionWithItemsHandler = { _, completed, _, _ in result(completed) }
    host.present(share, animated: true)
  }
}

private protocol SheetSizing {
  var detents: [UISheetPresentationController.Detent] { get }
}

/// Finishes a Flutter result exactly once.
private final class OnceResult {
  private var result: FlutterResult?
  init(_ result: @escaping FlutterResult) { self.result = result }
  func finish(_ value: Any?) {
    result?(value)
    result = nil
  }
}

private final class OptionSheetController: UITableViewController, UIAdaptivePresentationControllerDelegate, SheetSizing {
  private let options: [String]
  private let subtitles: [String]
  private let glyphs: [Int]
  private let fonts: [String]
  private let selected: Int
  private let done: OnceResult

  init(args: [String: Any], completion: @escaping FlutterResult) {
    options = args["options"] as? [String] ?? []
    subtitles = args["subtitles"] as? [String] ?? []
    glyphs = args["glyphs"] as? [Int] ?? []
    fonts = args["fonts"] as? [String] ?? []
    selected = args["selected"] as? Int ?? -1
    done = OnceResult(completion)
    super.init(style: .insetGrouped)
    title = args["title"] as? String
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  var detents: [UISheetPresentationController.Detent] {
    let height = CGFloat(options.count) * (subtitles.isEmpty ? 52 : 64) + 120
    return [.custom { context in min(height, context.maximumDetentValue) }, .large()]
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = .clear
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.close(nil) })
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
    var content = cell.defaultContentConfiguration()
    content.text = options[indexPath.row]
    if indexPath.row < subtitles.count, !subtitles[indexPath.row].isEmpty {
      content.secondaryText = subtitles[indexPath.row]
      content.secondaryTextProperties.color = .secondaryLabel
    }
    if indexPath.row < glyphs.count, indexPath.row < fonts.count, glyphs[indexPath.row] > 0,
       let image = PhosphorGlyph.image(code: glyphs[indexPath.row], family: fonts[indexPath.row], size: 24) {
      content.image = image
      content.imageProperties.tintColor = indexPath.row == selected ? playersLime : .label
      content.imageToTextPadding = 14
    }
    content.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
    cell.contentConfiguration = content
    // Translucent rows read as glass at partial height; the large detent is opaque dark.
    cell.backgroundColor = UIColor(white: 1, alpha: 0.06)
    cell.accessoryType = indexPath.row == selected ? .checkmark : .none
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    UISelectionFeedbackGenerator().selectionChanged()
    close(indexPath.row)
  }

  private func close(_ value: Int?) {
    done.finish(value)
    dismiss(animated: true)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    done.finish(nil)
  }
}

private final class DateSheetController: UIViewController, UIAdaptivePresentationControllerDelegate, SheetSizing {
  private let picker = UIDatePicker()
  private let isTime: Bool
  private let done: OnceResult

  init(args: [String: Any], completion: @escaping FlutterResult) {
    isTime = (args["mode"] as? String) == "time"
    done = OnceResult(completion)
    super.init(nibName: nil, bundle: nil)
    title = args["title"] as? String
    picker.datePickerMode = isTime ? .time : .date
    picker.preferredDatePickerStyle = isTime ? .wheels : .inline
    picker.minuteInterval = (args["minuteInterval"] as? Int) ?? 5
    if let initial = args["initial"] as? NSNumber {
      picker.date = Date(timeIntervalSince1970: initial.doubleValue / 1000)
    }
    if let minimum = args["minimum"] as? NSNumber {
      picker.minimumDate = Date(timeIntervalSince1970: minimum.doubleValue / 1000)
    }
    if let maximum = args["maximum"] as? NSNumber {
      picker.maximumDate = Date(timeIntervalSince1970: maximum.doubleValue / 1000)
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  var detents: [UISheetPresentationController.Detent] {
    isTime ? [.custom { _ in 300 }] : [.custom { _ in 470 }, .large()]
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    picker.tintColor = playersLime
    picker.addTarget(self, action: #selector(changed), for: .valueChanged)
    picker.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(picker)
    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      picker.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
      picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
    ])
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
        self?.done.finish(nil)
        self?.dismiss(animated: true)
      })
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .done, primaryAction: UIAction { [weak self] _ in
        guard let self else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        self.done.finish(self.picker.date.timeIntervalSince1970 * 1000)
        self.dismiss(animated: true)
      })
  }

  @objc private func changed() {
    // Wheels tick on their own; the inline calendar needs explicit feedback.
    if !isTime { UISelectionFeedbackGenerator().selectionChanged() }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    done.finish(nil)
  }
}

// MARK: - Phosphor glyphs

/// Renders Phosphor icons (the same TTFs Flutter bundles) as template images,
/// so native glass controls use the app's icon family instead of SF Symbols.
enum PhosphorGlyph {
  private static var names: [String: String] = [:]
  private static let files = [
    "PhosphorRegular": "Phosphor.ttf",
    "PhosphorBold": "Phosphor-Bold.ttf",
    "PhosphorFill": "Phosphor-Fill.ttf",
    "PhosphorLight": "Phosphor-Light.ttf",
    "PhosphorThin": "Phosphor-Thin.ttf",
  ]

  private static func postScriptName(_ family: String) -> String? {
    if let name = names[family] { return name }
    guard let file = files[family] else { return nil }
    let key = FlutterDartProject.lookupKey(forAsset: "lib/fonts/\(file)", fromPackage: "phosphoricons_flutter")
    guard let path = Bundle.main.path(forResource: key, ofType: nil),
          let provider = CGDataProvider(filename: path),
          let font = CGFont(provider),
          let name = font.postScriptName as String? else { return nil }
    // Fails harmlessly if already registered.
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, nil)
    names[family] = name
    return name
  }

  /// Reads `<prefix>glyph` / `<prefix>font` (or `glyph` / `font`) from Flutter args.
  static func image(_ args: [String: Any], prefix: String = "", size: CGFloat) -> UIImage? {
    let glyphKey = prefix.isEmpty ? "glyph" : "\(prefix)Glyph"
    let fontKey = prefix.isEmpty ? "font" : "\(prefix)Font"
    guard let code = (args[glyphKey] as? NSNumber)?.intValue, code > 0,
          let family = args[fontKey] as? String else { return nil }
    return image(code: code, family: family, size: size)
  }

  static func image(code: Int, family: String, size: CGFloat) -> UIImage? {
    guard let name = postScriptName(family),
          let font = UIFont(name: name, size: size),
          let scalar = UnicodeScalar(code) else { return nil }
    let text = String(Character(scalar)) as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
    let measured = text.size(withAttributes: attributes)
    let canvas = CGSize(width: size, height: size)
    let image = UIGraphicsImageRenderer(size: canvas).image { _ in
      text.draw(at: CGPoint(x: (canvas.width - measured.width) / 2,
                            y: (canvas.height - measured.height) / 2),
                withAttributes: attributes)
    }
    return image.withRenderingMode(.alwaysTemplate)
  }
}

// MARK: - Glass radius slider (expanding capsule)

/// A glass capsule ("◌ 5 km") that stretches into a thin slider when tapped
/// and shrinks back shortly after the finger lifts.
final class GlassSliderFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassSlider(frame: frame, id: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

private final class GlassSliderView: UIView {
  let effectView = UIVisualEffectView(effect: nil)
  let icon = UIImageView()
  let valueLabel = UILabel()
  let slider = UISlider()
  var expanded = false
  var collapsedWidth: CGFloat = 96

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    overrideUserInterfaceStyle = .dark
    let glass = UIGlassEffect()
    glass.isInteractive = true
    effectView.effect = glass
    effectView.cornerConfiguration = .capsule()
    effectView.clipsToBounds = true
    addSubview(effectView)
    icon.tintColor = .white
    icon.contentMode = .center
    valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
    valueLabel.textColor = .white
    slider.minimumTrackTintColor = playersLime
    slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.18)
    slider.alpha = 0
    [icon, valueLabel, slider].forEach { effectView.contentView.addSubview($0) }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  /// Content keeps its expanded layout; the capsule width reveals it.
  override func layoutSubviews() {
    super.layoutSubviews()
    let h = bounds.height
    let width = expanded ? bounds.width : min(collapsedWidth, bounds.width)
    effectView.frame = CGRect(x: 0, y: 0, width: width, height: h)
    icon.frame = CGRect(x: 12, y: 0, width: 22, height: h)
    valueLabel.frame = CGRect(x: 38, y: 0, width: 54, height: h)
    let sliderX: CGFloat = 96
    slider.frame = CGRect(x: sliderX, y: 0, width: max(0, bounds.width - sliderX - 18), height: h)
    slider.alpha = expanded ? 1 : 0
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Outside the capsule, let touches fall through.
    effectView.frame.contains(point) ? super.hitTest(point, with: event) : nil
  }
}

final class GlassSlider: NSObject, FlutterPlatformView, UIGestureRecognizerDelegate {
  private let root: GlassSliderView
  private let channel: FlutterMethodChannel
  private var unit = "km"
  private var lastSent = 0
  private var collapseTimer: Timer?
  private var tracking = false

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    root = GlassSliderView(frame: frame)
    root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    channel = FlutterMethodChannel(name: "playerszwz/glass-slider/\(id)", binaryMessenger: messenger)
    super.init()
    unit = arguments["unit"] as? String ?? "km"
    root.collapsedWidth = CGFloat((arguments["collapsedWidth"] as? NSNumber)?.doubleValue ?? 96)
    root.icon.image = PhosphorGlyph.image(arguments, size: 18)
    root.slider.minimumValue = Float((arguments["min"] as? NSNumber)?.doubleValue ?? 1)
    root.slider.maximumValue = Float((arguments["max"] as? NSNumber)?.doubleValue ?? 25)
    setValue(Float((arguments["value"] as? NSNumber)?.doubleValue ?? 5))
    root.effectView.isAccessibilityElement = true
    root.effectView.accessibilityTraits = .button
    root.effectView.accessibilityHint = "Opens a slider"
    root.effectView.accessibilityLabel = arguments["label"] as? String ?? "Search radius"

    root.slider.addTarget(self, action: #selector(changed), for: .valueChanged)
    root.slider.addTarget(self, action: #selector(touchStarted), for: .touchDown)
    root.slider.addTarget(self, action: #selector(touchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    tap.delegate = self
    root.effectView.addGestureRecognizer(tap)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "update":
        if let value = (call.arguments as? NSNumber)?.floatValue, !self.tracking { self.setValue(value) }
        result(nil)
      case "collapse":
        self.collapse()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    collapseTimer?.invalidate()
    channel.setMethodCallHandler(nil)
  }

  private func setValue(_ value: Float) {
    root.slider.value = value
    lastSent = Int(value.rounded())
    root.valueLabel.text = "\(lastSent) \(unit)"
    root.effectView.accessibilityValue = "\(lastSent) \(unit)"
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    !(touch.view is UISlider) && touch.view?.isDescendant(of: root.slider) != true
  }

  @objc private func tapped() {
    if root.expanded {
      collapse()
      return
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    // The platform view is always full width; only the capsule animates.
    channel.invokeMethod("expanded", arguments: nil)
    expand()
  }

  private func animate(_ changes: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
    if UIAccessibility.isReduceMotionEnabled {
      UIView.animate(withDuration: 0.2, animations: changes, completion: completion)
    } else {
      UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.78,
                     initialSpringVelocity: 0.4, options: [.allowUserInteraction, .beginFromCurrentState],
                     animations: changes, completion: completion)
    }
  }

  private func expand() {
    root.setNeedsLayout()
    root.layoutIfNeeded()
    animate {
      self.root.expanded = true
      self.root.layoutIfNeeded()
    }
    scheduleCollapse(after: 3)
  }

  private func collapse() {
    guard root.expanded else { return }
    collapseTimer?.invalidate()
    animate({
      self.root.expanded = false
      self.root.layoutIfNeeded()
    }, completion: { [weak self] _ in
      guard let self else { return }
      self.channel.invokeMethod("collapsed", arguments: self.lastSent)
    })
  }

  private func scheduleCollapse(after seconds: TimeInterval) {
    collapseTimer?.invalidate()
    collapseTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
      self?.collapse()
    }
  }

  @objc private func touchStarted() {
    tracking = true
    collapseTimer?.invalidate()
  }

  @objc private func touchEnded() {
    tracking = false
    scheduleCollapse(after: 1.4)
  }

  @objc private func changed() {
    let rounded = Int(root.slider.value.rounded())
    guard rounded != lastSent else { return }
    lastSent = rounded
    root.valueLabel.text = "\(rounded) \(unit)"
    root.effectView.accessibilityValue = "\(rounded) \(unit)"
    UISelectionFeedbackGenerator().selectionChanged()
    channel.invokeMethod("valueChanged", arguments: rounded)
  }

  func view() -> UIView { root }
}

// MARK: - App fonts (Inter) for native controls

enum AppFont {
  private static var names: [String: String] = [:]

  /// Inter from the Flutter bundle, so native controls match Flutter text.
  static func inter(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let file: String
    switch weight {
    case .bold, .heavy, .black: file = "Inter-Bold.ttf"
    case .semibold: file = "Inter-SemiBold.ttf"
    case .medium: file = "Inter-Medium.ttf"
    default: file = "Inter-Regular.ttf"
    }
    if names[file] == nil {
      let key = FlutterDartProject.lookupKey(forAsset: "assets/fonts/\(file)")
      if let path = Bundle.main.path(forResource: key, ofType: nil),
         let provider = CGDataProvider(filename: path),
         let font = CGFont(provider),
         let name = font.postScriptName as String? {
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: path) as CFURL, .process, nil)
        names[file] = name
      }
    }
    if let name = names[file], let font = UIFont(name: name, size: size) { return font }
    return .systemFont(ofSize: size, weight: weight)
  }
}

// MARK: - Glass segmented control

/// System UISegmentedControl: on iOS 26 its thumb is Liquid Glass, like the tab bar.
final class GlassSegmentedFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassSegmented(frame: frame, id: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

final class GlassSegmented: NSObject, FlutterPlatformView {
  private let container: UIView
  private let control: UISegmentedControl
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    container = UIView(frame: frame)
    control = UISegmentedControl(items: arguments["options"] as? [String] ?? [])
    channel = FlutterMethodChannel(name: "playerszwz/segmented/\(id)", binaryMessenger: messenger)
    super.init()
    container.backgroundColor = .clear
    container.overrideUserInterfaceStyle = .dark
    control.frame = container.bounds
    control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let size = CGFloat((arguments["fontSize"] as? NSNumber)?.doubleValue ?? 14)
    control.setTitleTextAttributes([.foregroundColor: UIColor(white: 1, alpha: 0.85),
                                    .font: AppFont.inter(size, weight: .medium)], for: .normal)
    control.setTitleTextAttributes([.foregroundColor: playersLime,
                                    .font: AppFont.inter(size, weight: .semibold)], for: .selected)
    control.selectedSegmentIndex = arguments["selected"] as? Int ?? 0
    control.isEnabled = arguments["enabled"] as? Bool ?? true
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    container.addSubview(control)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      if call.method == "update" {
        if let index = args["selected"] as? Int, index != self.control.selectedSegmentIndex {
          self.control.selectedSegmentIndex = index
        }
        if let enabled = args["enabled"] as? Bool { self.control.isEnabled = enabled }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  @objc private func changed() {
    UISelectionFeedbackGenerator().selectionChanged()
    channel.invokeMethod("changed", arguments: control.selectedSegmentIndex)
  }

  func view() -> UIView { container }
}

// MARK: - Anchored menu (Files-style UIMenu)

/// Button that reports when its menu actually appears and closes.
private final class MenuAnchorButton: UIButton {
  var onShow: (() -> Void)?
  var onEnd: (() -> Void)?

  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                       willDisplayMenuFor configuration: UIContextMenuConfiguration,
                                       animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    onShow?()
  }

  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                       willEndFor configuration: UIContextMenuConfiguration,
                                       animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    if let animator {
      animator.addCompletion { [weak self] in self?.onEnd?() }
    } else {
      onEnd?()
    }
  }
}

/// Compact popover list, used only if the system menu cannot be shown.
private final class MenuPopoverController: UITableViewController, UIPopoverPresentationControllerDelegate {
  private let items: [(String, String?, UIImage?, Bool, Bool)]
  private let done: OnceResult

  init(items: [(String, String?, UIImage?, Bool, Bool)], done: OnceResult) {
    self.items = items
    self.done = done
    super.init(style: .plain)
    modalPresentationStyle = .popover
    preferredContentSize = CGSize(width: 250, height: CGFloat(items.count) * 46)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = .clear
    tableView.isScrollEnabled = false
    tableView.rowHeight = 46
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = items[indexPath.row]
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = .clear
    var content = cell.defaultContentConfiguration()
    content.text = item.0
    content.textProperties.font = AppFont.inter(16, weight: .regular)
    content.textProperties.color = item.3 ? .systemRed : .label
    cell.contentConfiguration = content
    if let image = item.2 {
      let view = UIImageView(image: image)
      view.tintColor = item.3 ? .systemRed : .label
      cell.accessoryView = view
    }
    if item.4 { cell.accessoryType = .checkmark }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    UISelectionFeedbackGenerator().selectionChanged()
    done.finish(indexPath.row)
    dismiss(animated: true)
  }

  func adaptivePresentationStyle(for controller: UIPresentationController,
                                 traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    done.finish(nil)
  }
}

extension NativeSheets {
  /// Shows a system UIMenu anchored to a Flutter rect (Files-app style,
  /// Liquid Glass on iOS 26). Returns the chosen index or nil.
  func presentMenu(_ args: [String: Any], on host: UIViewController, result: @escaping FlutterResult) {
    guard let window = host.view.window else {
      result(nil)
      return
    }
    let done = OnceResult(result)
    let titles = args["actions"] as? [String] ?? []
    let subtitles = args["subtitles"] as? [String] ?? []
    let destructive = args["destructive"] as? [Bool] ?? []
    let selected = args["selected"] as? Int ?? -1
    let glyphs = args["glyphs"] as? [Int] ?? []
    let fonts = args["fonts"] as? [String] ?? []
    let rect = CGRect(x: (args["x"] as? NSNumber)?.doubleValue ?? 0,
                      y: (args["y"] as? NSNumber)?.doubleValue ?? 0,
                      width: (args["width"] as? NSNumber)?.doubleValue ?? 1,
                      height: (args["height"] as? NSNumber)?.doubleValue ?? 1)
    var chosen: Int?

    func image(_ i: Int) -> UIImage? {
      guard i < glyphs.count, i < fonts.count, glyphs[i] > 0 else { return nil }
      return PhosphorGlyph.image(code: glyphs[i], family: fonts[i], size: 20)
    }

    let actions: [UIMenuElement] = titles.enumerated().map { index, title in
      let action = UIAction(title: title, image: image(index)) { _ in
        chosen = index
        UISelectionFeedbackGenerator().selectionChanged()
      }
      if index < subtitles.count, !subtitles[index].isEmpty { action.subtitle = subtitles[index] }
      if index < destructive.count, destructive[index] { action.attributes = .destructive }
      if index == selected { action.state = .on }
      return action
    }
    let title = args["title"] as? String ?? ""
    let menu = UIMenu(title: title, options: .displayInline, children: actions)

    let anchor = MenuAnchorButton(type: .custom)
    anchor.frame = rect
    anchor.backgroundColor = .clear
    anchor.isAccessibilityElement = false
    anchor.overrideUserInterfaceStyle = .dark
    anchor.menu = menu
    anchor.showsMenuAsPrimaryAction = true
    window.addSubview(anchor)

    var shown = false
    anchor.onShow = { shown = true }
    anchor.onEnd = { [weak anchor] in
      // Actions run before the end animation completes.
      DispatchQueue.main.async {
        done.finish(chosen)
        anchor?.removeFromSuperview()
      }
    }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    anchor.performPrimaryAction()

    // If the system menu did not appear, fall back to a compact popover.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak anchor] in
      guard !shown, let anchor else { return }
      anchor.removeFromSuperview()
      let items = titles.enumerated().map { i, t in
        (t, i < subtitles.count ? subtitles[i] : nil, image(i),
         i < destructive.count && destructive[i], i == selected)
      }
      let popover = MenuPopoverController(items: items, done: done)
      popover.overrideUserInterfaceStyle = .dark
      if let presentation = popover.popoverPresentationController {
        presentation.sourceView = host.view
        presentation.sourceRect = host.view.convert(rect, from: window)
        presentation.permittedArrowDirections = [.up, .down]
        presentation.delegate = popover
      }
      host.present(popover, animated: true)
    }
  }
}
