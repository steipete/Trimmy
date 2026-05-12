import Foundation
import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
struct TrimmyTests {
    @Test
    func `detects multi line command`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        settings.preserveBlankLines = false
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\nls -la\n"
        #expect(detector.transformIfCommand(text) == "echo hi ls -la")
    }

    @Test
    func `skips single line`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.transformIfCommand("ls -la") == nil)
    }

    @Test
    func `skips long copies`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let blob = Array(repeating: "echo hi", count: 11).joined(separator: "\n")
        #expect(detector.transformIfCommand(blob) == nil)
    }

    @Test
    func `leaves structured json alone`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let json = """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
              ],
              "Resource": [
                "arn:aws:s3:::bucket-in-account-a",
                "arn:aws:s3:::bucket-in-account-a/*"
              ]
            }
          ]
        }
        """
        #expect(detector.transformIfCommand(json) == nil)
    }

    @Test
    func `preserves blank lines when enabled`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\n\necho bye\n"
        #expect(detector.transformIfCommand(text) == "echo hi\n\necho bye")
    }

    @Test
    func `flattens backslash continuations`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        python script.py \\
          --flag yes \\
          --count 2
        """
        #expect(detector.transformIfCommand(text) == "python script.py --flag yes --count 2")
    }

    @Test
    func `flattens indented continuation arguments`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        gog auth add
            steipete@gmail.com --services all --force-consent
        """
        #expect(detector.transformIfCommand(text) == "gog auth add steipete@gmail.com --services all --force-consent")
    }

    @Test
    func `repairs all caps token breaks`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "N\nODE_PATH=/usr/bin\nls"
        #expect(detector.transformIfCommand(text) == "NODE_PATH=/usr/bin ls")
    }

    @Test
    func `preserves space before flags after line wrap`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        go run ./cmd/metcli instagram feed sportg33k --inline --grid-cols 4 --thumb-cols 12
        --page-grid-size 40
        """
        let expected = [
            "go run ./cmd/metcli instagram feed sportg33k",
            "--inline --grid-cols 4 --thumb-cols 12 --page-grid-size 40",
        ].joined(separator: " ")
        #expect(
            detector.transformIfCommand(text)
                == expected)
    }

    @Test
    func `joins hyphen wrapped segments`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-
          f1a4ccda5f6a.png
        """
        #expect(detector
            .transformIfCommand(text) == "open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-f1a4ccda5f6a.png")
    }

    @Test
    func `does not merge list bullets`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        - item one
        - item two
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func `repair wrapped URL strips internal whitespace`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let url = "https://example.com/some-\n path?foo=1&bar= two"
        #expect(detector.repairWrappedURL(url) == "https://example.com/some-path?foo=1&bar=two")
    }

    @Test
    func `repair wrapped URL noop when already tight`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let url = "https://example.com/already-clean?x=1"
        #expect(detector.repairWrappedURL(url) == nil)
    }

    @Test
    func `repair wrapped URL rejects multiple schemes`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "https://one.com http://two.com"
        #expect(detector.repairWrappedURL(text) == nil)
    }

    @Test
    func `repair wrapped URL rejects when no scheme`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "example.com/foo bar"
        #expect(detector.repairWrappedURL(text) == nil)
    }

    @Test
    func `collapses blank lines when not preserved`() {
        let settings = AppSettings()
        settings.preserveBlankLines = false
        settings.generalAggressiveness = .high // allow flattening with minimal cues
        let detector = CommandDetector(settings: settings)
        let text = "echo a\n\necho b"
        #expect(detector.transformIfCommand(text) == "echo a echo b")
    }

    @Test
    func `ignores harmless multiline text`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low // stricter threshold to avoid flattening prose
        let detector = CommandDetector(settings: settings)
        let text = "Shopping list:\napples\noranges"
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func `pyenv init stays multiline at normal`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        export PYENV_ROOT="$HOME/.pyenv"
        [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init - zsh)"
        """
        #expect(detector.transformIfCommand(text) == nil)

        let forced = detector.transformIfCommand(text, aggressivenessOverride: .high)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `low aggressiveness needs clear signals`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hello
        world
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func `high aggressiveness flattens loose commands`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        npm
        install
        """
        #expect(detector.transformIfCommand(text) == "npm install")
    }

    @Test(arguments: Aggressiveness.allCases)
    func `aggressiveness thresholds`(_ level: Aggressiveness) {
        let settings = AppSettings()
        settings.generalAggressiveness = GeneralAggressiveness(rawValue: level.rawValue) ?? .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi \\
        --flag yes
        """
        let result = detector.transformIfCommand(text)
        #expect(result == "echo hi --flag yes")
    }

    @Test
    func `normal aggressiveness keeps non commands`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        Meeting notes:
        bullet
        items
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func `normal skips plain id lists`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let ids = """
        3c43356531
        0c25477230
        5837bc2cbe
        4006d4714a
        014b008f6a
        """
        #expect(detector.transformIfCommand(ids) == nil)
    }

    @Test
    func `skips longer multiline snippets in normal mode`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "curl https://example.com \\\n"
            + "  -H \"a: b\" \\\n"
            + "  -H \"c: d\" \\\n"
            + "  -H \"e: f\" \\\n"
            + "  -H \"g: h\""
        #expect(detector.transformIfCommand(text) == nil)

        let forced = detector.transformIfCommand(text, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `normal does not flatten swift snippet`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let swiftSnippet = """
        // MARK: Shape

        public extension Shape where Self == AnyShape {
            static var roundedContainer: some Shape {
                AnyShape(
                    .squircle(cornerRadius: .roundedCornerRadius)
                )
            }
        }
        """
        #expect(detector.transformIfCommand(swiftSnippet) == nil)

        let forced = detector.transformIfCommand(swiftSnippet, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("AnyShape") == true)
        #expect(forced != swiftSnippet, "forced: \(forced ?? "nil")")
    }

    @Test
    func `low skips code but high override allows it`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let code = """
        extension Foo {
            func bar() {
                print("hi")
            }
        }
        """
        #expect(detector.transformIfCommand(code) == nil)
        let forced = detector.transformIfCommand(code, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `normal skips struct definition`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let code = """
        struct Widget {
            let radius: Double
            var color: String
        }
        """
        #expect(detector.transformIfCommand(code) == nil)
    }

    @Test
    func `high override flattens struct definition`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let code = """
        struct Gadget {
            let id: UUID
            func render() { print(id) }
        }
        """
        let forced = detector.transformIfCommand(code, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `preserve blank lines round trip`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .high
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = """
        echo a \\
        --flag yes

        echo b
        """
        #expect(detector.transformIfCommand(text) == "echo a --flag yes\n\necho b")
    }

    @Test
    func `backslash without command should flatten only when high`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low
        let detectorLow = CommandDetector(settings: settings)
        let text = """
        Not really a command \\
        just text
        """
        #expect(detectorLow.transformIfCommand(text) == "Not really a command just text")

        let settingsHigh = AppSettings()
        settingsHigh.generalAggressiveness = .high
        let detectorHigh = CommandDetector(settings: settingsHigh)
        #expect(detectorHigh.transformIfCommand(text) == "Not really a command just text")
    }

    @Test
    func `removes box drawing characters`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world │ │ test"
        #expect(detector.cleanBoxDrawingCharacters(text) == "hello world test")
    }

    @Test
    func `returns nil when no box drawing characters`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "hello world test"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func `respects remove box drawing setting`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func `collapses extra spaces after stripping box drawing`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   │ │    hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi")
    }

    @Test
    func `box drawing removal is no op when disabled`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func `box drawing removal still allows command flattening`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        // Simulate a multi-line prompt wrapped with box characters.
        let text = """
        │ │ kubectl \\
        │ │   get pods
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned?.contains("kubectl \\") == true)
        // After cleaning, it should also flatten as a command.
        #expect(detector.transformIfCommand(cleaned ?? "") == "kubectl get pods")
    }

    @Test
    func `strips leading box runs across lines`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        │ ls -la \\
        │   | grep '^d'
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "ls -la \\\n | grep '^d'")
        #expect(detector.transformIfCommand(cleaned ?? "") == "ls -la | grep '^d'")
    }

    @Test
    func `strips trailing box runs across lines`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi │
        | tr h H │
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\n| tr h H")
        #expect(detector.transformIfCommand(cleaned ?? "") == "echo hi | tr h H")
    }

    @Test
    func `strips leading when most lines share gutter`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        │ echo hi
        │ cat file
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\ncat file\nplain line")
    }

    @Test
    func `strips trailing when most lines share gutter`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi │
        run thing │
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\nrun thing\nplain line")
    }

    @Test
    func `does not strip when gutter below majority`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        │ echo hi
        plain line
        plain line two
        """
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi\nplain line\nplain line two")
    }

    @Test
    func `strips single line with leading gutter`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ kubectl get pods"
        #expect(detector.cleanBoxDrawingCharacters(text) == "kubectl get pods")
    }

    @Test
    func `strips both sides when most lines do`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        │ ls -la │
        │   | grep '^d' │
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "ls -la\n | grep '^d'\nplain line")
        #expect(detector.transformIfCommand(cleaned ?? "") == "ls -la | grep '^d' plain line")
    }

    @Test
    func `ignores gutter detection on empty lines`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """

        │ echo hi

        │ cat file

        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\n\ncat file")
    }

    @Test
    func `strips leading and trailing box runs with mixed counts`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.generalAggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        ││ curl https://example.com │
        ││   | jq '.data' │
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "curl https://example.com\n | jq '.data'")
        #expect(detector.transformIfCommand(cleaned ?? "") == "curl https://example.com | jq '.data'")
    }

    @Test
    func `does not strip mid line box glyphs without shared gutter`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "echo │hi│ there"
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi there")
    }

    @Test
    func `box drawing removal does not strip legit pipes`() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "echo 1 | wc -l"
        // No box characters present; return nil and leave single pipe untouched.
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
        // Single-line input should not be flattened; ensure it remains untouched.
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func `summary ellipsizes long preview`() {
        let long = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        // limit 20 -> head 9, tail 10, plus ellipsis
        let truncated = ClipboardMonitor.ellipsize(long, limit: 20)
        #expect(truncated == "012345678…QRSTUVWXYZ")
        #expect(truncated.count == 20)
    }

    @Test
    func `summary does not ellipsize short preview`() {
        let text = "short preview"
        #expect(ClipboardMonitor.ellipsize(text, limit: 90) == text)
    }

    @Test
    func `strips prompt from single line command`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "# some-cli hello"
        #expect(detector.stripPromptPrefixes(text) == "some-cli hello")
    }

    @Test
    func `does not strip markdown heading`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.stripPromptPrefixes("# Release Notes") == nil)
    }

    @Test
    func `strips prompt across majority of lines`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        # brew install foo
        # brew install bar
        notes stay
        """
        #expect(
            detector.stripPromptPrefixes(text)
                == "brew install foo\nbrew install bar\nnotes stay")
    }

    @Test
    func `does not strip prompt when only one line looks like heading`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        # Release notes
        brew install foo
        """
        #expect(detector.stripPromptPrefixes(text) == nil)
    }

    // MARK: - Path Quoting Tests

    @Test
    func `quotes absolute path with spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "/Users/anton/My Documents/project"
        #expect(detector.quotePathWithSpaces(path) == "\"/Users/anton/My Documents/project\"")
    }

    @Test
    func `quotes home relative path with spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "~/Library/Application Support/SomeApp"
        #expect(detector.quotePathWithSpaces(path) == "\"~/Library/Application Support/SomeApp\"")
    }

    @Test
    func `quotes current dir relative path with spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "./My Project/src"
        #expect(detector.quotePathWithSpaces(path) == "\"./My Project/src\"")
    }

    @Test
    func `quotes parent dir relative path with spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "../Other Project/lib"
        #expect(detector.quotePathWithSpaces(path) == "\"../Other Project/lib\"")
    }

    @Test
    func `does not quote path without spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "/Users/anton/Documents/project"
        #expect(detector.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote already quoted path`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "\"/Users/anton/My Documents/project\""
        #expect(detector.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote already single quoted path`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "'/Users/anton/My Documents/project'"
        #expect(detector.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote multi line paths`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "/Users/anton/My Documents\n/another/path"
        #expect(detector.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote command with flags`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        // This looks like a command, not a path
        let text = "/usr/bin/ls -la /some/path"
        #expect(detector.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote command with path argument`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "cd /Users/anton/My Documents"
        #expect(detector.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote command with path argument without flags`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "open /Users/anton/My Documents"
        #expect(detector.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote sentence containing path`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "See /Users/anton/My Documents for details"
        #expect(detector.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote non path text`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "just some text with spaces"
        #expect(detector.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `escapes existing double quotes in path`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "/Users/anton/My \"Special\" Folder"
        #expect(detector.quotePathWithSpaces(path) == "\"/Users/anton/My \\\"Special\\\" Folder\"")
    }

    @Test
    func `trims whitespace before quoting`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "  /Users/anton/My Documents/project  \n"
        #expect(detector.quotePathWithSpaces(path) == "\"/Users/anton/My Documents/project\"")
    }

    @Test
    func `quotes relative path with spaces`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let path = "designcode.io/SwiftUI for iOS 17/Xcode Final/iOS17"
        #expect(detector.quotePathWithSpaces(path) == "\"designcode.io/SwiftUI for iOS 17/Xcode Final/iOS17\"")
    }

    @Test
    func `does not quote UR ls`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let url = "https://example.com/path with spaces"
        #expect(detector.quotePathWithSpaces(url) == nil)
    }
}
