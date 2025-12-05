import Foundation

public struct TrimConfig: Sendable {
    public var aggressiveness: Aggressiveness
    public var preserveBlankLines: Bool
    public var removeBoxDrawing: Bool

    public init(
        aggressiveness: Aggressiveness,
        preserveBlankLines: Bool,
        removeBoxDrawing: Bool)
    {
        self.aggressiveness = aggressiveness
        self.preserveBlankLines = preserveBlankLines
        self.removeBoxDrawing = removeBoxDrawing
    }
}
