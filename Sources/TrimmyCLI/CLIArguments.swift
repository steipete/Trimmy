import TrimmyCore

struct CLISettings {
    var aggressiveness: Aggressiveness = .normal
    var preserveBlankLines: Bool = false
    var removeBoxDrawing: Bool = true
}

struct CLIArgumentError: Error, CustomStringConvertible {
    let description: String
}

struct CLIArguments {
    private(set) var settings = CLISettings()
    private(set) var force = false
    private(set) var inputPath: String?
    private(set) var json = false

    init(_ arguments: [String]) throws {
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--trim":
                if let next = remaining.first,
                   !next.hasPrefix("--"),
                   !["-f", "-h", "-v"].contains(next)
                {
                    self.inputPath = remaining.popFirst()
                }
            case "-":
                self.inputPath = "-"
            case "--force", "-f":
                self.force = true
            case "--json":
                self.json = true
            case "--aggressiveness":
                guard let value = remaining.popFirst(),
                      let level = Aggressiveness(rawValue: value.lowercased())
                else {
                    throw CLIArgumentError(description: "--aggressiveness requires low, normal, or high.")
                }
                self.settings.aggressiveness = level
            case "--preserve-blank-lines":
                self.settings.preserveBlankLines = true
            case "--no-preserve-blank-lines":
                self.settings.preserveBlankLines = false
            case "--remove-box-drawing":
                self.settings.removeBoxDrawing = true
            case "--keep-box-drawing":
                self.settings.removeBoxDrawing = false
            default:
                throw CLIArgumentError(description: "Unknown argument: \(String(reflecting: argument)). Use --help.")
            }
        }
    }
}
