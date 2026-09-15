import Foundation
import TrimmyCore

struct CLITrimResult: Encodable {
    let original: String
    let trimmed: String
    let transformed: Bool
}

@main
struct TrimmyCLI {
    static let bundledVersion: String = {
        if let infoVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return infoVersion
        }
        return "0.11.1"
    }()

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--version") || args.contains("-v") {
            print("TrimmyCLI \(self.bundledVersion)")
            exit(0)
        }

        if args.contains("--help") || args.contains("-h") {
            print(self.helpText())
            return
        }

        let options: CLIArguments
        do {
            options = try CLIArguments(args)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }

        let input: String
        do {
            guard let text = try readInput(path: options.inputPath) else {
                FileHandle.standardError.write(Data("No input provided. Use --trim <file> or pipe to stdin.\n".utf8))
                exit(1)
            }
            input = text
        } catch {
            let source = if let path = options.inputPath, !path.isEmpty, path != "-" {
                "file \(String(reflecting: path))"
            } else {
                "stdin"
            }
            FileHandle.standardError.write(Data("Failed to read \(source): \(error.localizedDescription)\n".utf8))
            exit(1)
        }

        let result = cliTrim(input, settings: options.settings, force: options.force)

        if options.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            do {
                let data = try encoder.encode(result)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([0x0A]))
            } catch {
                FileHandle.standardError.write(Data("Failed to encode JSON: \(error)\n".utf8))
                exit(3)
            }
        } else {
            FileHandle.standardOutput.write(Data(result.trimmed.utf8))
            FileHandle.standardOutput.write(Data([0x0A]))
        }

        exit(result.transformed ? 0 : 2)
    }

    static func readInput(
        path: String?,
        isTTY: Bool = isatty(STDIN_FILENO) == 1,
        readStandardInput: () throws -> Data = { try FileHandle.standardInput.readToEnd() ?? Data() }) throws -> String?
    {
        if let path, !path.isEmpty, path != "-" {
            return try String(contentsOfFile: path, encoding: .utf8)
        }

        guard path == "-" || !isTTY else { return nil }
        let data = try readStandardInput()
        guard !data.isEmpty else { return nil }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

    static func helpText(version: String = TrimmyCLI.bundledVersion) -> String {
        """
        trimmy – flattens multi-line shell snippets so they execute
        Version: \(version)

        Usage:
          trimmy --trim [file] [options]    Trim input from file or stdin.

        Options:
          --trim <file>              Input file (optional; - or omitted reads stdin)
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
          0  transformation applied
          1  invalid arguments / no input / error reading
          2  no transformation applied (for callers who need to detect changes)
          3  JSON encoding error
        """
    }
}

// MARK: - Shared trimming

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
