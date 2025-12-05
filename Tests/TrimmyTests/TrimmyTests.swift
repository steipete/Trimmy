import Foundation
import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
@Suite
struct TrimmyTests {
    @Test
    func detectsMultiLineCommand() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = false
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\nls -la\n"
        #expect(detector.transformIfCommand(text) == "echo hi ls -la")
    }

    @Test
    func skipsSingleLine() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.transformIfCommand("ls -la") == nil)
    }

    @Test
    func skipsLongCopies() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let blob = Array(repeating: "echo hi", count: 11).joined(separator: "\n")
        #expect(detector.transformIfCommand(blob) == nil)
    }

    @Test
    func leavesStructuredJsonAlone() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func preservesBlankLinesWhenEnabled() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\n\necho bye\n"
        #expect(detector.transformIfCommand(text) == "echo hi\n\necho bye")
    }

    @Test
    func flattensBackslashContinuations() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        python script.py \\
          --flag yes \\
          --count 2
        """
        #expect(detector.transformIfCommand(text) == "python script.py --flag yes --count 2")
    }

    @Test
    func repairsAllCapsTokenBreaks() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "N\nODE_PATH=/usr/bin\nls"
        #expect(detector.transformIfCommand(text) == "NODE_PATH=/usr/bin ls")
    }

    @Test
    func joinsHyphenWrappedSegments() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-
          f1a4ccda5f6a.png
        """
        #expect(detector
            .transformIfCommand(text) == "open src/statics/qrcode/scan-qr-f1cc4328-eb1d-4a3c-9bd2-f1a4ccda5f6a.png")
    }

    @Test
    func doesNotMergeListBullets() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        - item one
        - item two
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func repairWrappedURLStripsInternalWhitespace() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let url = "https://example.com/some-\n path?foo=1&bar= two"
        #expect(detector.repairWrappedURL(url) == "https://example.com/some-path?foo=1&bar=two")
    }

    @Test
    func repairWrappedURLNoopWhenAlreadyTight() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let url = "https://example.com/already-clean?x=1"
        #expect(detector.repairWrappedURL(url) == nil)
    }

    @Test
    func repairWrappedURLRejectsMultipleSchemes() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "https://one.com http://two.com"
        #expect(detector.repairWrappedURL(text) == nil)
    }

    @Test
    func repairWrappedURLRejectsWhenNoScheme() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "example.com/foo bar"
        #expect(detector.repairWrappedURL(text) == nil)
    }

    @Test
    func collapsesBlankLinesWhenNotPreserved() {
        let settings = AppSettings()
        settings.preserveBlankLines = false
        settings.aggressiveness = .high // allow flattening with minimal cues
        let detector = CommandDetector(settings: settings)
        let text = "echo a\n\necho b"
        #expect(detector.transformIfCommand(text) == "echo a echo b")
    }

    @Test
    func ignoresHarmlessMultilineText() {
        let settings = AppSettings()
        settings.aggressiveness = .low // stricter threshold to avoid flattening prose
        let detector = CommandDetector(settings: settings)
        let text = "Shopping list:\napples\noranges"
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func pyenvInitStaysMultilineAtNormal() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func lowAggressivenessNeedsClearSignals() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hello
        world
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func highAggressivenessFlattensLooseCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        npm
        install
        """
        #expect(detector.transformIfCommand(text) == "npm install")
    }

    @Test(arguments: Aggressiveness.allCases)
    func aggressivenessThresholds(_ level: Aggressiveness) {
        let settings = AppSettings()
        settings.aggressiveness = level
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi \\
        --flag yes
        """
        let result = detector.transformIfCommand(text)
        #expect(result == "echo hi --flag yes")
    }

    @Test
    func normalAggressivenessKeepsNonCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        Meeting notes:
        bullet
        items
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func normalSkipsPlainIdLists() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func skipsLongerMultilineSnippetsInNormalMode() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        line1
        line2
        line3
        line4
        line5
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func normalDoesNotFlattenSwiftSnippet() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func lowSkipsCodeButHighOverrideAllowsIt() {
        let settings = AppSettings()
        settings.aggressiveness = .low
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
    func normalSkipsStructDefinition() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func highOverrideFlattensStructDefinition() {
        let settings = AppSettings()
        settings.aggressiveness = .low
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
    func preserveBlankLinesRoundTrip() {
        let settings = AppSettings()
        settings.aggressiveness = .high
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
    func backslashWithoutCommandShouldFlattenOnlyWhenHigh() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detectorLow = CommandDetector(settings: settings)
        let text = """
        Not really a command \\
        just text
        """
        #expect(detectorLow.transformIfCommand(text) == "Not really a command just text")

        let settingsHigh = AppSettings()
        settingsHigh.aggressiveness = .high
        let detectorHigh = CommandDetector(settings: settingsHigh)
        #expect(detectorHigh.transformIfCommand(text) == "Not really a command just text")
    }

    @Test
    func removesBoxDrawingCharacters() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world │ │ test"
        #expect(detector.cleanBoxDrawingCharacters(text) == "hello world test")
    }

    @Test
    func returnsNilWhenNoBoxDrawingCharacters() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "hello world test"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func respectsRemoveBoxDrawingSetting() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func collapsesExtraSpacesAfterStrippingBoxDrawing() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   │ │    hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi")
    }

    @Test
    func boxDrawingRemovalIsNoOpWhenDisabled() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func boxDrawingRemovalStillAllowsCommandFlattening() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
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
    func stripsLeadingBoxRunsAcrossLines() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
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
    func stripsTrailingBoxRunsAcrossLines() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
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
    func stripsLeadingWhenMostLinesShareGutter() {
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
    func stripsTrailingWhenMostLinesShareGutter() {
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
    func doesNotStripWhenGutterBelowMajority() {
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
    func stripsSingleLineWithLeadingGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ kubectl get pods"
        #expect(detector.cleanBoxDrawingCharacters(text) == "kubectl get pods")
    }

    @Test
    func stripsBothSidesWhenMostLinesDo() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
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
    func ignoresGutterDetectionOnEmptyLines() {
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
    func stripsLeadingAndTrailingBoxRunsWithMixedCounts() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
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
    func doesNotStripMidLineBoxGlyphsWithoutSharedGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "echo │hi│ there"
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi there")
    }

    @Test
    func boxDrawingRemovalDoesNotStripLegitPipes() {
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
    func summaryEllipsizesLongPreview() {
        let long = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        // limit 20 -> head 9, tail 10, plus ellipsis
        let truncated = ClipboardMonitor.ellipsize(long, limit: 20)
        #expect(truncated == "012345678…QRSTUVWXYZ")
        #expect(truncated.count == 20)
    }

    @Test
    func summaryDoesNotEllipsizeShortPreview() {
        let text = "short preview"
        #expect(ClipboardMonitor.ellipsize(text, limit: 90) == text)
    }

    @Test
    func stripsPromptFromSingleLineCommand() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "# some-cli hello"
        #expect(detector.stripPromptPrefixes(text) == "some-cli hello")
    }

    @Test
    func doesNotStripMarkdownHeading() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.stripPromptPrefixes("# Release Notes") == nil)
    }

    @Test
    func stripsPromptAcrossMajorityOfLines() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
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
    func doesNotStripPromptWhenOnlyOneLineLooksLikeHeading() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        # Release notes
        brew install foo
        """
        #expect(detector.stripPromptPrefixes(text) == nil)
    }
}
