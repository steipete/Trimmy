import Foundation

public struct TrimConfig: Sendable {
    public var aggressiveness: Aggressiveness
    public var preserveBlankLines: Bool
    public var removeBoxDrawing: Bool
    public var boxDrawingChars: String
    public var trimPathSuffix: Bool
    public var formatHeredoc: Bool

    public static let defaultBoxDrawingChars = "│┃╎╏┆┇┊┋╽╿￨｜"

    public init(
        aggressiveness: Aggressiveness,
        preserveBlankLines: Bool,
        removeBoxDrawing: Bool,
        boxDrawingChars: String = TrimConfig.defaultBoxDrawingChars,
        trimPathSuffix: Bool = true,
        formatHeredoc: Bool = true)
    {
        self.aggressiveness = aggressiveness
        self.preserveBlankLines = preserveBlankLines
        self.removeBoxDrawing = removeBoxDrawing
        self.boxDrawingChars = boxDrawingChars
        self.trimPathSuffix = trimPathSuffix
        self.formatHeredoc = formatHeredoc
    }
}
