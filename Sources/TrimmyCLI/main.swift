import Foundation
import TrimmyCore

struct CLISettings {
    var aggressiveness: Aggressiveness = .normal
    var preserveBlankLines: Bool = false
    var removeBoxDrawing: Bool = true
}

struct CLITrimResult { let original: String; let trimmed: String; let transformed: Bool }

@main
struct TrimmyCLI {
    private static let bundledVersion: String = {
        if let infoVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return infoVersion
        }
        return "0.6.0"
    }()

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        var force = false
        var inputPath: String?
        var json = false
        var settings = CLISettings()

        if args.contains("--version") || args.contains("-v") {
            print("TrimmyCLI \(self.bundledVersion)")
            exit(0)
        }

        var idx = 0
        while idx < args.count {
            switch args[idx] {
            case "--trim":
                if idx + 1 < args.count, !args[idx + 1].hasPrefix("--") {
                    inputPath = args[idx + 1]; idx += 1
                }
            case "--force", "-f":
                force = true
            case "--json":
                json = true
            case "--aggressiveness":
                if idx + 1 < args.count, let aggr = Aggressiveness(rawValue: args[idx + 1].lowercased()) {
                    settings.aggressiveness = aggr; idx += 1
                }
            case "--preserve-blank-lines":
                settings.preserveBlankLines = true
            case "--no-preserve-blank-lines":
                settings.preserveBlankLines = false
            case "--remove-box-drawing":
                settings.removeBoxDrawing = true
            case "--keep-box-drawing":
                settings.removeBoxDrawing = false
            case "--help", "-h":
                self.printHelp(); return
            default: break
            }
            idx += 1
        }

        guard let input = readInput(path: inputPath) else {
            FileHandle.standardError.write(Data("No input provided. Use --trim <file> or pipe to stdin.\n".utf8))
            exit(1)
        }

        let result = cliTrim(input, settings: settings, force: force)

        if json {
            let payload: [String: Any] = [
                "original": result.original,
                "trimmed": result.trimmed,
                "transformed": result.transformed,
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([0x0A]))
            } catch {
                FileHandle.standardError.write(Data("Failed to encode JSON: \(error)\n".utf8))
                exit(3)
            }
        } else {
            FileHandle.standardOutput.write(result.trimmed.data(using: String.Encoding.utf8) ?? Data())
            FileHandle.standardOutput.write(Data([0x0A]))
        }

        exit(result.transformed ? 0 : 2)
    }

    private static func readInput(
        path: String?,
        stdinData: Data? = nil,
        isTTY: Bool = isatty(STDIN_FILENO) == 1) -> String?
    {
        if let path, !path.isEmpty {
            return try? String(contentsOfFile: path, encoding: .utf8)
        }

        if isTTY {
            guard let data = stdinData, !data.isEmpty else { return nil }
            return String(data: data, encoding: .utf8)
        }

        let data = stdinData ?? FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    #if DEBUG
    static func _testReadInput(path: String?, stdinData: Data?, isTTY: Bool) -> String? {
        self.readInput(path: path, stdinData: stdinData, isTTY: isTTY)
    }

    static var _testVersion: String { self.bundledVersion }
    #endif

    static func helpText(version: String = TrimmyCLI.bundledVersion) -> String {
        """
        trimmy – flattens multi-line shell snippets so they execute
        Version: \(version)

        Usage:
          trimmy --trim [file] [options]    Trim input from file or stdin.

        Options:
          --trim <file>              Input file (optional; stdin if omitted)
          --force, -f                Force High aggressiveness
          --aggressiveness <level>   low | normal | high
          --preserve-blank-lines     Keep blank lines when flattening
          --no-preserve-blank-lines  Remove blank lines
          --remove-box-drawing       Strip box-drawing characters (default true)
          --keep-box-drawing         Disable box-drawing removal
          --json                     Emit JSON {original, trimmed, transformed}
          --version, -v              Print version
          --help, -h                 Show help

        Exit codes:
          0  trimmed (or unchanged if no transformations needed and force not requested)
          1  no input / error reading
          2  no transformation applied (for callers who need to detect changes)
        """
    }

    private static func printHelp() {
        print(self.helpText())
    }
}

// MARK: - Trimming pipeline (standalone, mirrors app heuristics)

func cliTrim(_ text: String, settings: CLISettings, force: Bool) -> CLITrimResult {
    let cleaner = TextCleaner()
    let override: Aggressiveness? = force ? .high : nil
    let cfg = TrimConfig(
        aggressiveness: settings.aggressiveness,
        preserveBlankLines: settings.preserveBlankLines,
        removeBoxDrawing: settings.removeBoxDrawing)
    let result = cleaner.transform(text, config: cfg, aggressivenessOverride: override)
    return CLITrimResult(original: result.original, trimmed: result.trimmed, transformed: result.wasTransformed)
}
