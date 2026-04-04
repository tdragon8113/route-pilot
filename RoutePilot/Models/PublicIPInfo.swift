//
//  PublicIPInfo.swift
//  RoutePilot
//

import Foundation

/// 公网 IP 信息
struct PublicIPInfo: Codable {
    let status: String
    let country: String
    let city: String
    let isp: String
    let query: String

    /// 是否查询成功
    var isSuccess: Bool {
        status == "success"
    }
}