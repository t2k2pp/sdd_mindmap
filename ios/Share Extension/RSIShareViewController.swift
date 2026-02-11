import UIKit
import Social
import Photos
import AVFoundation
import MobileCoreServices
import UniformTypeIdentifiers

public let kSchemePrefix = "ShareMedia"
public let kUserDefaultsKey = "ShareKey"
public let kUserDefaultsMessageKey = "ShareMessageKey"
public let kAppGroupIdKey = "AppGroupId"

public class SharedMediaFile: Codable {
  var path: String
  var mimeType: String?
  var thumbnail: String?
  var duration: Double?
  var message: String?
  var type: SharedMediaType

  public init(
    path: String,
    mimeType: String? = nil,
    thumbnail: String? = nil,
    duration: Double? = nil,
    message: String? = nil,
    type: SharedMediaType
  ) {
    self.path = path
    self.mimeType = mimeType
    self.thumbnail = thumbnail
    self.duration = duration
    self.message = message
    self.type = type
  }
}

public enum SharedMediaType: String, Codable, CaseIterable {
  case image
  case video
  case text
  case file
  case url

  var toUTTypeIdentifier: String {
    if #available(iOS 14.0, *) {
      switch self {
      case .image:
        return UTType.image.identifier
      case .video:
        return UTType.movie.identifier
      case .text:
        return UTType.text.identifier
      case .file:
        return UTType.fileURL.identifier
      case .url:
        return UTType.url.identifier
      }
    }
    switch self {
    case .image:
      return "public.image"
    case .video:
      return "public.movie"
    case .text:
      return "public.text"
    case .file:
      return "public.file-url"
    case .url:
      return "public.url"
    }
  }
}

@available(swift, introduced: 5.0)
open class RSIShareViewController: SLComposeServiceViewController {
  var hostAppBundleIdentifier = ""
  var appGroupId = ""
  var sharedMedia: [SharedMediaFile] = []

  open func shouldAutoRedirect() -> Bool {
    return true
  }

  open override func isContentValid() -> Bool {
    return true
  }

  open override func viewDidLoad() {
    super.viewDidLoad()
    loadIds()
  }

  open override func didSelectPost() {
    saveAndRedirect(message: contentText)
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if let content = extensionContext?.inputItems.first as? NSExtensionItem,
      let contents = content.attachments
    {
      for (index, attachment) in contents.enumerated() {
        for type in SharedMediaType.allCases {
          if attachment.hasItemConformingToTypeIdentifier(type.toUTTypeIdentifier) {
            attachment.loadItem(forTypeIdentifier: type.toUTTypeIdentifier) { [weak self] data, error in
              guard let this = self, error == nil else {
                self?.dismissWithError()
                return
              }
              switch type {
              case .text:
                if let text = data as? String {
                  this.handleMedia(forLiteral: text, type: type, index: index, content: content)
                }
              case .url:
                if let url = data as? URL {
                  this.handleMedia(forLiteral: url.absoluteString, type: type, index: index, content: content)
                }
              default:
                if let url = data as? URL {
                  this.handleMedia(forFile: url, type: type, index: index, content: content)
                } else if let image = data as? UIImage {
                  this.handleMedia(forUIImage: image, type: type, index: index, content: content)
                }
              }
            }
            break
          }
        }
      }
    }
  }

  open override func configurationItems() -> [Any]! {
    return []
  }

  private func loadIds() {
    let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    if let idx = shareExtensionAppBundleIdentifier.lastIndex(of: ".") {
      hostAppBundleIdentifier = String(shareExtensionAppBundleIdentifier[..<idx])
    } else {
      hostAppBundleIdentifier = shareExtensionAppBundleIdentifier
    }

    let defaultAppGroupId = "group.\(hostAppBundleIdentifier)"
    let customAppGroupId = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
    appGroupId = customAppGroupId ?? defaultAppGroupId
  }

  private func handleMedia(forLiteral item: String, type: SharedMediaType, index: Int, content: NSExtensionItem) {
    sharedMedia.append(SharedMediaFile(path: item, mimeType: type == .text ? "text/plain" : nil, type: type))
    if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
      saveAndRedirect()
    }
  }

  private func handleMedia(forUIImage image: UIImage, type: SharedMediaType, index: Int, content: NSExtensionItem) {
    guard let tempPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
      .appendingPathComponent("TempImage.png")
    else { return }

    if writeTempFile(image, to: tempPath) {
      let newPathDecoded = tempPath.absoluteString.removingPercentEncoding ?? tempPath.absoluteString
      sharedMedia.append(SharedMediaFile(path: newPathDecoded, mimeType: type == .image ? "image/png" : nil, type: type))
    }

    if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
      saveAndRedirect()
    }
  }

  private func handleMedia(forFile url: URL, type: SharedMediaType, index: Int, content: NSExtensionItem) {
    let fileName = getFileName(from: url, type: type)
    guard let newPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
      .appendingPathComponent(fileName)
    else { return }

    if copyFile(at: url, to: newPath) {
      let newPathDecoded = newPath.absoluteString.removingPercentEncoding ?? newPath.absoluteString
      if type == .video, let info = getVideoInfo(from: url) {
        let thumbnailPathDecoded = info.thumbnail?.removingPercentEncoding
        sharedMedia.append(
          SharedMediaFile(
            path: newPathDecoded,
            mimeType: url.mimeType(),
            thumbnail: thumbnailPathDecoded,
            duration: info.duration,
            type: type
          ))
      } else {
        sharedMedia.append(SharedMediaFile(path: newPathDecoded, mimeType: url.mimeType(), type: type))
      }
    }

    if index == (content.attachments?.count ?? 0) - 1, shouldAutoRedirect() {
      saveAndRedirect()
    }
  }

  private func saveAndRedirect(message: String? = nil) {
    let userDefaults = UserDefaults(suiteName: appGroupId)
    if let data = try? JSONEncoder().encode(sharedMedia) {
      userDefaults?.set(data, forKey: kUserDefaultsKey)
    }
    userDefaults?.set(message, forKey: kUserDefaultsMessageKey)
    userDefaults?.synchronize()
    redirectToHostApp()
  }

  private func redirectToHostApp() {
    loadIds()
    guard let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share") else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }

    var responder: UIResponder? = self
    if #available(iOS 18.0, *) {
      while responder != nil {
        if let application = responder as? UIApplication {
          application.open(url, options: [:], completionHandler: nil)
        }
        responder = responder?.next
      }
    } else {
      let selectorOpenURL = sel_registerName("openURL:")
      while responder != nil {
        if responder?.responds(to: selectorOpenURL) == true {
          _ = responder?.perform(selectorOpenURL, with: url)
        }
        responder = responder?.next
      }
    }

    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func dismissWithError() {
    let alert = UIAlertController(title: "Error", message: "Error loading data", preferredStyle: .alert)
    let action = UIAlertAction(title: "Close", style: .cancel) { _ in
      self.dismiss(animated: true)
    }
    alert.addAction(action)
    present(alert, animated: true)
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func getFileName(from url: URL, type: SharedMediaType) -> String {
    var name = url.lastPathComponent
    if name.isEmpty {
      switch type {
      case .image:
        name = UUID().uuidString + ".png"
      case .video:
        name = UUID().uuidString + ".mp4"
      case .text:
        name = UUID().uuidString + ".txt"
      default:
        name = UUID().uuidString
      }
    }
    return name
  }

  private func writeTempFile(_ image: UIImage, to dstURL: URL) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: dstURL.path) {
        try FileManager.default.removeItem(at: dstURL)
      }
      try image.pngData()?.write(to: dstURL)
      return true
    } catch {
      return false
    }
  }

  private func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: dstURL.path) {
        try FileManager.default.removeItem(at: dstURL)
      }
      try FileManager.default.copyItem(at: srcURL, to: dstURL)
      return true
    } catch {
      return false
    }
  }

  private func getVideoInfo(from url: URL) -> (thumbnail: String?, duration: Double)? {
    let asset = AVAsset(url: url)
    let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
    let thumbnailPath = getThumbnailPath(for: url)

    if FileManager.default.fileExists(atPath: thumbnailPath.path) {
      return (thumbnailPath.absoluteString, duration)
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 360, height: 360)

    do {
      let image = try generator.copyCGImage(at: CMTimeMakeWithSeconds(0.6, preferredTimescale: 1), actualTime: nil)
      try UIImage(cgImage: image).pngData()?.write(to: thumbnailPath)
      return (thumbnailPath.absoluteString, duration)
    } catch {
      return nil
    }
  }

  private func getThumbnailPath(for url: URL) -> URL {
    let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "==", with: "")
    return FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
      .appendingPathComponent("\(fileName).jpg")
  }
}

private extension URL {
  func mimeType() -> String {
    if #available(iOS 14.0, *) {
      if let mimeType = UTType(filenameExtension: pathExtension)?.preferredMIMEType {
        return mimeType
      }
    } else {
      if let uti = UTTypeCreatePreferredIdentifierForTag(
        kUTTagClassFilenameExtension,
        pathExtension as NSString,
        nil
      )?.takeRetainedValue(),
        let mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()
      {
        return mime as String
      }
    }
    return "application/octet-stream"
  }
}
