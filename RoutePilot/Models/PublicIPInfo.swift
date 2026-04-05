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

    /// 手动初始化
    init(status: String, country: String, city: String, isp: String, query: String) {
        self.status = status
        self.country = country
        self.city = city
        self.isp = isp
        self.query = query
    }
}