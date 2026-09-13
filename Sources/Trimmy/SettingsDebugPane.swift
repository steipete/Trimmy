#if DEBUG
import SwiftUI

@MainActor
struct DebugSettingsPane: View {
    @ObservedObject var monitor: ClipboardMonitor

    private let sampleOriginal = """
    docker run \\
      --rm \\
      --volume ~/.aws:/root/.aws \\
      --env AWS_PROFILE=prod \\
      amazon/aws-cli s3 ls
    """

    private let sampleTrimmed = "docker run --rm --volume ~/.aws:/root/.aws --env AWS_PROFILE=prod amazon/aws-cli s3 ls"

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Preview tools",
                subtitle: "Development-only actions for testing menu previews and animation.")
            {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Load strikeout sample") {
                        self.monitor.debugSetPreview(original: self.sampleOriginal, trimmed: self.sampleTrimmed)
                    }

                    Button("Trigger trim animation") {
                        self.monitor.triggerTrimPulse()
                    }
                }
            }
        }
    }
}
#endif
