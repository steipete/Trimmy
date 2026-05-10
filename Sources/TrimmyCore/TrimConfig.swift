import Foundation

public struct TrimConfig: Sendable {
    public var aggressiveness: Aggressiveness
    public var preserveBlankLines: Bool
    public var removeBoxDrawing: Bool
    public var flattenClaudeCodePrompts: Bool

    public init(
        aggressiveness: Aggressiveness,
        preserveBlankLines: Bool,
        removeBoxDrawing: Bool,
        flattenClaudeCodePrompts: Bool = true)
    {
        self.aggressiveness = aggressiveness
        self.preserveBlankLines = preserveBlankLines
        self.removeBoxDrawing = removeBoxDrawing
        self.flattenClaudeCodePrompts = flattenClaudeCodePrompts
    }
}
