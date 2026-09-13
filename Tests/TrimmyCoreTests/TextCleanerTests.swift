import Foundation
import Testing
import TrimmyCore

struct TextCleanerTests {
    private let cleaner = TextCleaner()

    @Test
    func `detects multi line command`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "echo hi\nls -la\n"
        #expect(self.cleaner.transformIfCommand(text, config: config) == "echo hi ls -la")
    }

    @Test
    func `skips single line`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(self.cleaner.transformIfCommand("ls -la", config: config) == nil)
    }

    @Test
    func `skips long copies`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let blob = Array(repeating: "echo hi", count: 11).joined(separator: "\n")
        #expect(self.cleaner.transformIfCommand(blob, config: config) == nil)
    }

    @Test
    func `leaves structured json alone`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
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
        #expect(self.cleaner.transformIfCommand(json, config: config) == nil)
    }

    @Test
    func `preserves blank lines when enabled`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: true, removeBoxDrawing: true)
        let text = "echo hi\n\necho bye\n"
        #expect(self.cleaner.transformIfCommand(text, config: config) == "echo hi\n\necho bye")
    }

    @Test
    func `flattens backslash continuations`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        python script.py \\
          --flag yes \\
          --count 2
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == "python script.py --flag yes --count 2")
    }

    @Test
    func `flattens indented continuation arguments`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        gog auth add
            steipete@gmail.com --services all --force-consent
        """
        #expect(self.cleaner
            .transformIfCommand(text, config: config) ==
            "gog auth add steipete@gmail.com --services all --force-consent")
    }

    @Test
    func `repairs all caps token breaks`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "N\nODE_PATH=/usr/bin\nls"
        #expect(self.cleaner.transformIfCommand(text, config: config) == "NODE_PATH=/usr/bin ls")
    }

    @Test
    func `preserves space before flags after line wrap`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        go run ./cmd/metcli instagram feed sportg33k --inline --grid-cols 4 --thumb-cols 12
        --page-grid-size 40
        """
        let expected = [
            "go run ./cmd/metcli instagram feed sportg33k",
            "--inline --grid-cols 4 --thumb-cols 12 --page-grid-size 40",
        ].joined(separator: " ")
        #expect(
            self.cleaner.transformIfCommand(text, config: config)
                == expected)
    }

    @Test
    func `joins hyphen wrapped segments`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-
          f1a4ccda5f6a.png
        """
        #expect(self.cleaner
            .transformIfCommand(text, config: config) ==
            "open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-f1a4ccda5f6a.png")
    }

    @Test
    func `does not merge list bullets`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        - item one
        - item two
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)
    }

    @Test
    func `repair wrapped URL strips internal whitespace`() {
        let url = "https://example.com/some-\n path?foo=1&bar= two"
        #expect(self.cleaner.repairWrappedURL(url) == "https://example.com/some-path?foo=1&bar=two")
    }

    @Test
    func `repair wrapped URL noop when already tight`() {
        let url = "https://example.com/already-clean?x=1"
        #expect(self.cleaner.repairWrappedURL(url) == nil)
    }

    @Test
    func `repair wrapped URL rejects multiple schemes`() {
        let text = "https://one.com http://two.com"
        #expect(self.cleaner.repairWrappedURL(text) == nil)
    }

    @Test
    func `repair wrapped URL rejects when no scheme`() {
        let text = "example.com/foo bar"
        #expect(self.cleaner.repairWrappedURL(text) == nil)
    }

    @Test
    func `collapses blank lines when not preserved`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "echo a\n\necho b"
        #expect(self.cleaner.transformIfCommand(text, config: config) == "echo a echo b")
    }

    @Test
    func `ignores harmless multiline text`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "Shopping list:\napples\noranges"
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)
    }

    @Test
    func `pyenv init stays multiline at normal`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        export PYENV_ROOT="$HOME/.pyenv"
        [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init - zsh)"
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)

        let forced = self.cleaner.transformIfCommand(text, config: config, aggressivenessOverride: .high)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `low aggressiveness needs clear signals`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        echo hello
        world
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)
    }

    @Test
    func `high aggressiveness flattens loose commands`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        npm
        install
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == "npm install")
    }

    @Test(arguments: Aggressiveness.allCases)
    func `aggressiveness thresholds`(_ level: Aggressiveness) {
        let config = TrimConfig(aggressiveness: level, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        echo hi \\
        --flag yes
        """
        let result = self.cleaner.transformIfCommand(text, config: config)
        #expect(result == "echo hi --flag yes")
    }

    @Test
    func `normal aggressiveness keeps non commands`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        Meeting notes:
        bullet
        items
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)
    }

    @Test
    func `normal skips plain id lists`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let ids = """
        3c43356531
        0c25477230
        5837bc2cbe
        4006d4714a
        014b008f6a
        """
        #expect(self.cleaner.transformIfCommand(ids, config: config) == nil)
    }

    @Test
    func `skips longer multiline snippets in normal mode`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "curl https://example.com \\\n"
            + "  -H \"a: b\" \\\n"
            + "  -H \"c: d\" \\\n"
            + "  -H \"e: f\" \\\n"
            + "  -H \"g: h\""
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)

        let forced = self.cleaner.transformIfCommand(text, config: config, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `normal does not flatten swift snippet`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
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
        #expect(self.cleaner.transformIfCommand(swiftSnippet, config: config) == nil)

        let forced = self.cleaner.transformIfCommand(swiftSnippet, config: config, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("AnyShape") == true)
        #expect(forced != swiftSnippet, "forced: \(forced ?? "nil")")
    }

    @Test
    func `low skips code but high override allows it`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let code = """
        extension Foo {
            func bar() {
                print("hi")
            }
        }
        """
        #expect(self.cleaner.transformIfCommand(code, config: config) == nil)
        let forced = self.cleaner.transformIfCommand(code, config: config, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `normal skips struct definition`() {
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let code = """
        struct Widget {
            let radius: Double
            var color: String
        }
        """
        #expect(self.cleaner.transformIfCommand(code, config: config) == nil)
    }

    @Test
    func `high override flattens struct definition`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let code = """
        struct Gadget {
            let id: UUID
            func render() { print(id) }
        }
        """
        let forced = self.cleaner.transformIfCommand(code, config: config, aggressivenessOverride: .high)
        #expect(forced != nil)
        #expect(forced?.contains("\n") == false)
    }

    @Test
    func `preserve blank lines round trip`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: true, removeBoxDrawing: true)
        let text = """
        echo a \\
        --flag yes

        echo b
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == "echo a --flag yes\n\necho b")
    }

    @Test
    func `backslash continuation flattens at low and high`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        Not really a command \\
        just text
        """
        #expect(self.cleaner.transformIfCommand(text, config: config) == "Not really a command just text")

        let highConfig = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(self.cleaner.transformIfCommand(text, config: highConfig) == "Not really a command just text")
    }

    @Test
    func `removes box drawing characters`() {
        let text = "hello │ │ world │ │ test"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: true) == "hello world test")
    }

    @Test
    func `returns nil when no box drawing characters`() {
        let text = "hello world test"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: true) == nil)
    }

    @Test
    func `respects remove box drawing setting`() {
        let text = "hello │ │ world"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: false) == nil)
    }

    @Test
    func `collapses extra spaces after stripping box drawing`() {
        let text = "│ │ echo   │ │    hi │ │"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: true) == "echo hi")
    }

    @Test
    func `box drawing removal is no op when disabled`() {
        let text = "│ │ echo   hi │ │"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: false) == nil)
    }

    @Test
    func `box drawing removal still allows command flattening`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        // Simulate a multi-line prompt wrapped with box characters.
        let text = """
        │ │ kubectl \\
        │ │   get pods
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing)
        #expect(cleaned?.contains("kubectl \\") == true)
        // After cleaning, it should also flatten as a command.
        #expect(self.cleaner.transformIfCommand(cleaned ?? "", config: config) == "kubectl get pods")
    }

    @Test
    func `strips leading box runs across lines`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        │ ls -la \\
        │   | grep '^d'
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing)
        #expect(cleaned == "ls -la \\\n | grep '^d'")
        #expect(self.cleaner.transformIfCommand(cleaned ?? "", config: config) == "ls -la | grep '^d'")
    }

    @Test
    func `strips trailing box runs across lines`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        echo hi │
        | tr h H │
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing)
        #expect(cleaned == "echo hi\n| tr h H")
        #expect(self.cleaner.transformIfCommand(cleaned ?? "", config: config) == "echo hi | tr h H")
    }

    @Test
    func `strips leading when most lines share gutter`() {
        let text = """
        │ echo hi
        │ cat file
        plain line
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: true)
        #expect(cleaned == "echo hi\ncat file\nplain line")
    }

    @Test
    func `strips trailing when most lines share gutter`() {
        let text = """
        echo hi │
        run thing │
        plain line
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: true)
        #expect(cleaned == "echo hi\nrun thing\nplain line")
    }

    @Test
    func `does not strip when gutter below majority`() {
        let text = """
        │ echo hi
        plain line
        plain line two
        """
        #expect(self.cleaner
            .cleanBoxDrawingCharacters(text, enabled: true) == "echo hi\nplain line\nplain line two")
    }

    @Test
    func `strips single line with leading gutter`() {
        let text = "│ kubectl get pods"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: true) == "kubectl get pods")
    }

    @Test
    func `strips both sides when most lines do`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        │ ls -la │
        │   | grep '^d' │
        plain line
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing)
        #expect(cleaned == "ls -la\n | grep '^d'\nplain line")
        #expect(self.cleaner.transformIfCommand(cleaned ?? "", config: config) == "ls -la | grep '^d' plain line")
    }

    @Test
    func `ignores gutter detection on empty lines`() {
        let text = """

        │ echo hi

        │ cat file

        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: true)
        #expect(cleaned == "echo hi\n\ncat file")
    }

    @Test
    func `strips leading and trailing box runs with mixed counts`() {
        let config = TrimConfig(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let text = """
        ││ curl https://example.com │
        ││   | jq '.data' │
        """
        let cleaned = self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing)
        #expect(cleaned == "curl https://example.com\n | jq '.data'")
        #expect(self.cleaner
            .transformIfCommand(cleaned ?? "", config: config) == "curl https://example.com | jq '.data'")
    }

    @Test
    func `does not strip mid line box glyphs without shared gutter`() {
        let text = "echo │hi│ there"
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: true) == "echo hi there")
    }

    @Test
    func `box drawing removal does not strip legit pipes`() {
        let config = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        let text = "echo 1 | wc -l"
        // No box characters present; return nil and leave single pipe untouched.
        #expect(self.cleaner.cleanBoxDrawingCharacters(text, enabled: config.removeBoxDrawing) == nil)
        // Single-line input should not be flattened; ensure it remains untouched.
        #expect(self.cleaner.transformIfCommand(text, config: config) == nil)
    }

    @Test
    func `strips prompt from single line command`() {
        let text = "# some-cli hello"
        #expect(self.cleaner.stripPromptPrefixes(text) == "some-cli hello")
    }

    @Test
    func `does not strip markdown heading`() {
        #expect(self.cleaner.stripPromptPrefixes("# Release Notes") == nil)
    }

    @Test
    func `strips prompt across majority of lines`() {
        let text = """
        # brew install foo
        # brew install bar
        notes stay
        """
        #expect(
            self.cleaner.stripPromptPrefixes(text)
                == "brew install foo\nbrew install bar\nnotes stay")
    }

    @Test
    func `does not strip prompt when only one line looks like heading`() {
        let text = """
        # Release notes
        brew install foo
        """
        #expect(self.cleaner.stripPromptPrefixes(text) == nil)
    }

    // MARK: - Path Quoting Tests

    @Test
    func `quotes absolute path with spaces`() {
        let path = "/Users/anton/My Documents/project"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"/Users/anton/My Documents/project\"")
    }

    @Test
    func `quotes home relative path with spaces`() {
        let path = "~/Library/Application Support/SomeApp"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"~/Library/Application Support/SomeApp\"")
    }

    @Test
    func `quotes current dir relative path with spaces`() {
        let path = "./My Project/src"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"./My Project/src\"")
    }

    @Test
    func `quotes parent dir relative path with spaces`() {
        let path = "../Other Project/lib"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"../Other Project/lib\"")
    }

    @Test
    func `does not quote path without spaces`() {
        let path = "/Users/anton/Documents/project"
        #expect(self.cleaner.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote already quoted path`() {
        let path = "\"/Users/anton/My Documents/project\""
        #expect(self.cleaner.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote already single quoted path`() {
        let path = "'/Users/anton/My Documents/project'"
        #expect(self.cleaner.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote multi line paths`() {
        let path = "/Users/anton/My Documents\n/another/path"
        #expect(self.cleaner.quotePathWithSpaces(path) == nil)
    }

    @Test
    func `does not quote command with flags`() {
        // This looks like a command, not a path
        let text = "/usr/bin/ls -la /some/path"
        #expect(self.cleaner.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote command with path argument`() {
        let text = "cd /Users/anton/My Documents"
        #expect(self.cleaner.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote command with path argument without flags`() {
        let text = "open /Users/anton/My Documents"
        #expect(self.cleaner.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote sentence containing path`() {
        let text = "See /Users/anton/My Documents for details"
        #expect(self.cleaner.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `does not quote non path text`() {
        let text = "just some text with spaces"
        #expect(self.cleaner.quotePathWithSpaces(text) == nil)
    }

    @Test
    func `escapes existing double quotes in path`() {
        let path = "/Users/anton/My \"Special\" Folder"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"/Users/anton/My \\\"Special\\\" Folder\"")
    }

    @Test
    func `trims whitespace before quoting`() {
        let path = "  /Users/anton/My Documents/project  \n"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"/Users/anton/My Documents/project\"")
    }

    @Test
    func `quotes relative path with spaces`() {
        let path = "designcode.io/SwiftUI for iOS 17/Xcode Final/iOS17"
        #expect(self.cleaner.quotePathWithSpaces(path) == "\"designcode.io/SwiftUI for iOS 17/Xcode Final/iOS17\"")
    }

    @Test
    func `does not quote UR ls`() {
        let url = "https://example.com/path with spaces"
        #expect(self.cleaner.quotePathWithSpaces(url) == nil)
    }
}
