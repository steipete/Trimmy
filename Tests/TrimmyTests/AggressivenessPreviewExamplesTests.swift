import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
struct AggressivenessPreviewExamplesTests {
    @Test
    func `low example flattens to single line`() {
        let sample = AggressivenessExample.example(for: Aggressiveness.low).sample
        let flattened = AggressivenessPreviewEngine.previewAfter(
            for: sample,
            level: .low,
            preserveBlankLines: false,
            removeBoxDrawing: true)
        #expect(flattened == "ls -la | grep '^d' > dirs.txt")
    }

    @Test
    func `normal example matches expectation`() {
        let sample = AggressivenessExample.example(for: Aggressiveness.normal).sample
        let flattened = AggressivenessPreviewEngine.previewAfter(
            for: sample,
            level: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true)
        #expect(flattened == "kubectl get pods -n kube-system | jq '.items[].metadata.name'")
    }

    @Test
    func `high example collapses loose commands`() {
        let sample = AggressivenessExample.example(for: Aggressiveness.high).sample
        let flattened = AggressivenessPreviewEngine.previewAfter(
            for: sample,
            level: .high,
            preserveBlankLines: false,
            removeBoxDrawing: true)
        #expect(flattened == "echo \"hello\" print status")
    }

    @Test
    func `preview collapses path line breaks`() {
        let sample = """
        ssh steipete@192.168.64.2 'chmod 600 ~/.ssh/github_rsa && chmod 644 ~/.ssh/
        github_rsa.pub'
        """
        let flattened = AggressivenessPreviewEngine.previewAfter(
            for: sample,
            level: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true)
        #expect(flattened ==
            "ssh steipete@192.168.64.2 'chmod 600 ~/.ssh/github_rsa && chmod 644 ~/.ssh/github_rsa.pub'")
    }
}
