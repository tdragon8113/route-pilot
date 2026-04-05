//
//  PublicIPView.swift
//  RoutePilot
//

import SwiftUI

/// 公网 IP 查询组件
struct PublicIPView: View {
    @State private var publicIPInfo: PublicIPInfo?
    @State private var isQueryingIP = false
    @State private var ipQueryError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tools.public_ip".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("tools.public_ip_desc".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            if isQueryingIP {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("tools.querying".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let info = publicIPInfo {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("result.ip".localized + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.query)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("result.location".localized + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(info.country), \(info.city)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("result.isp".localized + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.isp)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cardBackground)
                )
            }

            if let error = ipQueryError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(isQueryingIP ? "tools.querying".localized : "tools.query".localized) {
                queryPublicIP()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isQueryingIP)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
    }

    private func queryPublicIP() {
        isQueryingIP = true
        ipQueryError = nil

        guard let url = URL(string: "https://ipapi.co/json/") else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                await MainActor.run {
                    isQueryingIP = false
                    if let ip = json?["ip"] as? String {
                        publicIPInfo = PublicIPInfo(
                            status: "success",
                            country: json?["country_name"] as? String ?? "",
                            city: json?["city"] as? String ?? "",
                            isp: json?["org"] as? String ?? "",
                            query: ip
                        )
                    } else {
                        ipQueryError = "result.query_failed".localized
                    }
                }
            } catch {
                await MainActor.run {
                    isQueryingIP = false
                    ipQueryError = "result.query_failed_network".localized
                }
            }
        }
    }
}