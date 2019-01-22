import Foundation
import SourceKittenFramework

public struct RegexConfiguration: RuleConfiguration, Hashable, CacheDescriptionProvider {
    public let identifier: String
    public var name: String?
    public var message = "Regex matched."
    public var regex: NSRegularExpression!
    public var excludeRegex: NSRegularExpression?
    public var included: NSRegularExpression?
    public var excluded: NSRegularExpression?
    public var matchKinds = SyntaxKind.allKinds
    public var excludeKinds = Set<SyntaxKind>()

    public var severityConfiguration = SeverityConfiguration(.warning)

    public var severity: ViolationSeverity {
        return severityConfiguration.severity
    }

    public var consoleDescription: String {
        return "\(severity.rawValue): \(regex.pattern)"
    }

    internal var cacheDescription: String {
        let jsonObject: [String] = [
            identifier,
            name ?? "",
            message,
            regex.pattern,
            included?.pattern ?? "",
            excluded?.pattern ?? "",
            matchKinds.map({ $0.rawValue }).sorted(by: <).joined(separator: ","),
            severityConfiguration.consoleDescription
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
          let jsonString = String(data: jsonData, encoding: .utf8) {
              return jsonString
        }
        queuedFatalError("Could not serialize regex configuration for cache")
    }

    public var description: RuleDescription {
        return RuleDescription(identifier: identifier, name: name ?? identifier,
                               description: "", kind: .style)
    }

    public init(identifier: String) {
        self.identifier = identifier
    }

    public mutating func apply(configuration: Any) throws {
        guard let configurationDict = configuration as? [String: Any],
            let regexString = configurationDict["regex"] as? String else {
                throw ConfigurationError.unknownConfiguration
        }

        regex = try .cached(pattern: regexString)

        if let excludeRegexString = configurationDict["exclude_regex"] as? String {
            excludeRegex = try .cached(pattern: excludeRegexString)
        }

        if let includedString = configurationDict["included"] as? String {
            included = try .cached(pattern: includedString)
        }

        if let excludedString = configurationDict["excluded"] as? String {
            excluded = try .cached(pattern: excludedString)
        }

        if let name = configurationDict["name"] as? String {
            self.name = name
        }
        if let message = configurationDict["message"] as? String {
            self.message = message
        }
        if let matchKinds = [String].array(of: configurationDict["match_kinds"]) {
            self.matchKinds = Set(try matchKinds.flatMap({ try Set(shortName: $0) }))
        }
        if let excludeKinds = [String].array(of: configurationDict["exclude_kinds"]) {
            self.excludeKinds = Set(try excludeKinds.flatMap({ try Set(shortName: $0) }))
        }
        if let severityString = configurationDict["severity"] as? String {
            try severityConfiguration.apply(configuration: severityString)
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
