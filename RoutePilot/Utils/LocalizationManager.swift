//
//  LocalizationManager.swift
//  RoutePilot
//

import Foundation
import Combine

/// 语言选项
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"

    var displayName: String {
        switch self {
        case .system: return "language.system".localized
        case .chinese: return "language.chinese".localized
        case .english: return "language.english".localized
        }
    }
}

/// 国际化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            applyLanguage(currentLanguage)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
        applyLanguage(currentLanguage)
    }

    private func applyLanguage(_ language: AppLanguage) {
        let bundle: Bundle?

        switch language {
        case .system:
            bundle = nil
        case .chinese:
            bundle = Bundle(path: Bundle.main.path(forResource: "zh-Hans", ofType: "lproj") ?? "")
        case .english:
            bundle = Bundle(path: Bundle.main.path(forResource: "en", ofType: "lproj") ?? "")
        }

        if let bundle = bundle {
            LocalizationManager.bundle = bundle
        } else {
            LocalizationManager.bundle = Bundle.main
        }
    }

    /// 当前使用的语言包
    static var bundle: Bundle = Bundle.main
}

/// 国际化字符串扩展
extension String {
    var localized: String {
        NSLocalizedString(self, bundle: LocalizationManager.bundle, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, bundle: LocalizationManager.bundle, comment: ""), arguments: arguments)
    }

    /// 静态本地化方法（可在 actor 中使用）
    static func localizedStatic(_ key: String) -> String {
        NSLocalizedString(key, bundle: LocalizationManager.bundle, comment: "")
    }

    /// 静态格式化本地化方法（可在 actor 中使用）
    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: LocalizationManager.bundle, comment: ""), arguments: arguments)
    }
}