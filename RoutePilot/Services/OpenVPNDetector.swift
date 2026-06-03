//
//  OpenVPNDetector.swift
//  RoutePilot
//

import Foundation

struct OpenVPNConnection: Equatable {
    let name: String
    let interface: String?
    let client: String
}

/// Tunnelblick / standalone OpenVPN detection (not visible via scutil --nc list)
enum OpenVPNDetector {

    private static let tblkProfilePattern = #"([^/]+)\.tblk"#
    private static let tunDeviceLogPattern = #"TUN/TAP device (utun\d+) opened"#

    static func displayName(profile: String) -> String {
        "OpenVPN (\(profile))"
    }

    /// All known OpenVPN profiles from Tunnelblick configs and running processes.
    static func discoverOpenVPNProfiles() -> [String] {
        var profiles = Set<String>()

        for url in tunnelblickConfigurationDirectories() {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents where item.pathExtension == "tblk" {
                profiles.insert(item.deletingPathExtension().lastPathComponent)
            }
        }

        for process in parseOpenVPNProcesses() {
            profiles.insert(process.profile)
        }

        return profiles.sorted().map(displayName(profile:))
    }

    static func discoverActiveOpenVPNConnections(excludingInterfaces: Set<String> = []) -> [OpenVPNConnection] {
        let processes = parseOpenVPNProcesses()
        guard !processes.isEmpty else { return [] }

        var claimedInterfaces = excludingInterfaces
        var connections: [OpenVPNConnection] = []
        let unclaimedUtuns = utunInterfacesWithIPv4().filter { !claimedInterfaces.contains($0) }

        for process in processes {
            guard isProcessConnected(process, unclaimedUtuns: unclaimedUtuns) else { continue }

            let client = process.isTunnelblick ? "Tunnelblick" : "OpenVPN"
            var interface = interfaceFromLog(at: process.logPath)

            if interface == nil || claimedInterfaces.contains(interface!) {
                interface = firstUnclaimedUtunInterface(excluding: claimedInterfaces)
            }

            guard let interface else { continue }

            claimedInterfaces.insert(interface)

            connections.append(
                OpenVPNConnection(
                    name: displayName(profile: process.profile),
                    interface: interface,
                    client: client
                )
            )
        }

        return connections
    }

    static func resolveOpenVPNName(for interface: String, excludingInterfaces: Set<String>) -> String? {
        discoverActiveOpenVPNConnections(excludingInterfaces: excludingInterfaces)
            .first { $0.interface == interface }?
            .name
    }

    /// Interfaces already owned by connected system VPNs from scutil.
    static func systemConnectedVPNInterfaces() -> Set<String> {
        var interfaces = Set<String>()
        let output = runCommand("/usr/sbin/scutil --nc list")

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            guard lineStr.contains("(Connected)") else { continue }

            guard let vpnName = quotedName(in: lineStr) else { continue }
            let escapedName = vpnName.replacingOccurrences(of: "\"", with: "\\\"")
            let statusOutput = runCommand("/usr/sbin/scutil --nc status \"\(escapedName)\"")

            if let interface = interfaceName(in: statusOutput) {
                interfaces.insert(interface)
            }
        }

        return interfaces
    }

    // MARK: - Process parsing

    private struct ParsedOpenVPNProcess {
        let profile: String
        let isTunnelblick: Bool
        let managementHost: String?
        let managementPort: Int?
        let logPath: String?
    }

    private static func parseOpenVPNProcesses() -> [ParsedOpenVPNProcess] {
        let output = runCommand("ps aux")
        var processes: [ParsedOpenVPNProcess] = []
        var seenProfiles = Set<String>()

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            guard isOpenVPNProcessLine(lineStr),
                  !lineStr.contains("grep") else { continue }

            guard let configPath = argumentValue(in: lineStr, flag: "--config"),
                  let profile = profileName(fromConfigPath: configPath) else { continue }

            if seenProfiles.contains(profile) { continue }
            seenProfiles.insert(profile)

            let managementHost = argumentValue(in: lineStr, flag: "--management")
            let managementPort = argumentValue(in: lineStr, flag: "--management", valueIndex: 1).flatMap(Int.init)
            let logPath = argumentValue(in: lineStr, flag: "--log-append")
            let isTunnelblick = lineStr.localizedCaseInsensitiveContains("tunnelblick")
                || configPath.localizedCaseInsensitiveContains(".tblk")

            processes.append(
                ParsedOpenVPNProcess(
                    profile: profile,
                    isTunnelblick: isTunnelblick,
                    managementHost: managementHost,
                    managementPort: managementPort,
                    logPath: logPath
                )
            )
        }

        return processes
    }

    private static func isOpenVPNProcessLine(_ line: String) -> Bool {
        line.contains("/openvpn ") ||
        line.contains("/openvpn-") ||
        line.hasSuffix("/openvpn")
    }

    private static func isProcessConnected(_ process: ParsedOpenVPNProcess, unclaimedUtuns: [String]) -> Bool {
        if interfaceFromLog(at: process.logPath) != nil {
            return true
        }

        // Tunnelblick uses --management-hold; rely on log or active utun mapping.
        return parseOpenVPNProcesses().count == 1 && !unclaimedUtuns.isEmpty
    }

    // MARK: - Interface mapping

    private static func interfaceFromLog(at path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let escapedPath = shellEscaped(path)
        let tail = runCommand("tail -n 100 \(escapedPath) 2>/dev/null")
        guard !tail.isEmpty else { return nil }

        guard let regex = try? NSRegularExpression(pattern: tunDeviceLogPattern) else { return nil }
        let range = NSRange(tail.startIndex..., in: tail)
        guard let match = regex.matches(in: tail, range: range).last,
              let interfaceRange = Range(match.range(at: 1), in: tail) else {
            return nil
        }
        return String(tail[interfaceRange])
    }

    private static func firstUnclaimedUtunInterface(excluding: Set<String>) -> String? {
        utunInterfacesWithIPv4()
            .first { !excluding.contains($0) }
    }

    private static func utunInterfacesWithIPv4() -> [String] {
        let output = runCommand("/sbin/ifconfig")
        var interfaces: [String] = []
        var currentInterface: String?

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            if !lineStr.hasPrefix("\t"), lineStr.contains(":") {
                let name = lineStr.split(separator: ":").first.map(String.init)
                currentInterface = name?.hasPrefix("utun") == true ? name : nil
                continue
            }

            if lineStr.contains("inet "), let currentInterface {
                if !interfaces.contains(currentInterface) {
                    interfaces.append(currentInterface)
                }
            }
        }

        return interfaces
    }

    // MARK: - Profile discovery

    private static func tunnelblickConfigurationDirectories() -> [URL] {
        var directories: [URL] = []
        let fileManager = FileManager.default

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directories.append(
                appSupport.appendingPathComponent("Tunnelblick/Configurations", isDirectory: true)
            )
        }

        directories.append(URL(fileURLWithPath: "/Library/Application Support/Tunnelblick/Users", isDirectory: true))

        let username = NSUserName()
        if !username.isEmpty {
            directories.append(
                URL(fileURLWithPath: "/Library/Application Support/Tunnelblick/Users/\(username)", isDirectory: true)
            )
        }

        var expanded: [URL] = []
        for directory in directories {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            if directory.lastPathComponent == "Users" {
                if let userDirs = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    expanded.append(contentsOf: userDirs.filter { url in
                        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    })
                }
            } else {
                expanded.append(directory)
            }
        }

        return expanded
    }

    private static func profileName(fromConfigPath path: String) -> String? {
        if let tblkRegex = try? NSRegularExpression(pattern: tblkProfilePattern),
           let profile = firstMatch(in: path, regex: tblkRegex, group: 1) {
            return profile
        }

        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent
        return fileName.isEmpty ? nil : fileName
    }

    // MARK: - scutil helpers

    private static func quotedName(in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #""([^"]+)""#) else { return nil }
        return firstMatch(in: line, regex: regex, group: 1)
    }

    private static func interfaceName(in statusOutput: String) -> String? {
        for line in statusOutput.split(separator: "\n") {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            if lineStr.hasPrefix("InterfaceName") {
                return lineStr.split(separator: ":").dropFirst().first.map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    // MARK: - String helpers

    private static func argumentValue(in line: String, flag: String, valueIndex: Int = 0) -> String? {
        guard let flagRange = line.range(of: "\(flag) ") else { return nil }

        var remainder = String(line[flagRange.upperBound...].trimmingCharacters(in: .whitespaces))
        if let nextFlag = remainder.range(of: " --") {
            remainder = String(remainder[..<nextFlag.lowerBound])
        }

        // Path arguments may contain spaces; keep the full value.
        if flag == "--config" || flag == "--log-append" {
            guard valueIndex == 0 else { return nil }
            let value = remainder.trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        var tokens: [String] = []
        var current = String(remainder)

        while !current.isEmpty {
            if current.hasPrefix("\"") {
                current.removeFirst()
                guard let endQuote = current.firstIndex(of: "\"") else { return nil }
                tokens.append(String(current[..<endQuote]))
                current = String(current[current.index(after: endQuote)...])
                    .trimmingCharacters(in: .whitespaces)
            } else if let spaceIndex = current.firstIndex(of: " ") {
                tokens.append(String(current[..<spaceIndex]))
                current = String(current[current.index(after: spaceIndex)...])
                    .trimmingCharacters(in: .whitespaces)
            } else {
                tokens.append(current)
                break
            }
        }

        guard valueIndex >= 0, valueIndex < tokens.count else { return nil }
        let value = tokens[valueIndex]
        return value.isEmpty ? nil : value
    }

    private static func firstMatch(in text: String, regex: NSRegularExpression, group: Int) -> String? {
        let groups = firstMatchGroups(in: text, regex: regex, groupCount: group)
        guard group > 0, groups.count >= group else { return nil }
        return groups[group - 1]
    }

    private static func firstMatchGroups(in text: String, regex: NSRegularExpression, groupCount: Int) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return [] }

        var groups: [String] = []
        for index in 1...groupCount {
            guard let matchRange = Range(match.range(at: index), in: text) else { continue }
            groups.append(String(text[matchRange]))
        }
        return groups
    }

    private static func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runCommand(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
