//
//  LoginServiceKit.swift
//  RoutePilot
//
//  Based on LoginServiceKit by Clipy Project
//  https://github.com/Clipy/LoginServiceKit
//

import Cocoa

/// 登录项管理
enum LoginServiceKit {

    /// 检查是否已存在登录项
    static func isExistLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        return loginItem(at: path) != nil
    }

    /// 添加登录项
    @discardableResult
    static func addLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        guard !isExistLoginItems(at: path) else { return false }
        guard let snapshot = snapshot else { return false }
        let item = unsafeBitCast(snapshot.items.last, to: LSSharedFileListItem.self)
        return LSSharedFileListInsertItemURL(snapshot.list, item, nil, nil, URL(fileURLWithPath: path) as CFURL, nil, nil) != nil
    }

    /// 移除登录项
    @discardableResult
    static func removeLoginItems(at path: String = Bundle.main.bundlePath) -> Bool {
        guard isExistLoginItems(at: path) else { return false }
        guard let snapshot = snapshot else { return false }
        return snapshot.items.filter {
            LSSharedFileListItemCopyResolvedURL($0, 0, nil)?.takeRetainedValue() == (URL(fileURLWithPath: path) as CFURL)
        }.allSatisfy {
            LSSharedFileListItemRemove(snapshot.list, $0) == noErr
        }
    }

    // MARK: - Private

    private static var snapshot: (list: LSSharedFileList, items: [LSSharedFileListItem])? {
        guard let list = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() else {
            return nil
        }
        return (list, (LSSharedFileListCopySnapshot(list, nil)?.takeRetainedValue() as? [LSSharedFileListItem]) ?? [])
    }

    private static func loginItem(at path: String) -> LSSharedFileListItem? {
        return snapshot?.items.first { item in
            guard let url = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() else { return false }
            return URL(fileURLWithPath: path).absoluteString == (url as URL).absoluteString
        }
    }
}