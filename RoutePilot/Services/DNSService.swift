//
//  DNSService.swift
//  RoutePilot
//

import Foundation

/// DNS 解析服务
actor DNSService {
    static let shared = DNSService()

    private init() {}

    /// 判断字符串是否为域名（静态方法，不需要 actor 隔离）
    static func isDomain(_ text: String) -> Bool {
        // 包含 / 则是 CIDR
        if text.contains("/") { return false }

        // 检查是否像域名（包含点且不是纯 IP）
        if !text.contains(".") { return false }

        // 尝试解析为 IP，失败则认为是域名
        // 简单判断：如果包含字母，则是域名
        let hasLetter = text.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        return hasLetter
    }

    /// 解析域名获取所有 IP 地址
    /// - Parameter domain: 域名（不含协议）
    /// - Returns: IP 地址数组
    func resolve(domain: String) async -> [String] {
        // 移除可能的前缀
        let cleanDomain = domain
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        // 使用 host 命令解析
        let output = await ShellRunner.shared.runWithOutput("host -t A \(cleanDomain) 2>/dev/null | grep 'has address' | awk '{print $4}'")

        guard !output.isEmpty else { return [] }

        // 解析输出
        var results: [String] = []
        for line in output.components(separatedBy: "\n") {
            let ip = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 简单验证 IP 格式
            if isValidIPv4(ip) {
                results.append(ip)
            }
        }

        return results
    }

    /// 验证是否为有效的 IPv4 地址
    private func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let num = Int(part), num >= 0, num <= 255 else {
                return false
            }
        }

        return true
    }
}