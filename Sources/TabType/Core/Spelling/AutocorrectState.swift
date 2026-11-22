import Foundation

/// What autocorrect may touch, kept beside the engine's keystroke buffer:
/// - only a word typed in one go since the caret last jumped (arrows, clicks),
///   so a correction never backspaces over text the buffer didn't really see;
/// - never a word the author reverted after it was corrected.
struct AutocorrectState {
    /// Buffer characters before this index were typed before the last caret jump.
    private(set) var floor = 0
    /// The last correction and the buffer length right after it.
    private(set) var last: (original: String, corrected: String, end: Int)?
    /// Lowercased words the author put back after a correction.
    private(set) var rejected: Set<String>

    init(rejected: Set<String> = []) { self.rejected = rejected }

    /// The caret moved without typing: nothing typed so far is next to it any more.
    mutating func caretJumped(bufferCount: Int) {
        floor = bufferCount
        last = nil
    }

    /// A backspace, with the buffer length before it. Backspacing into a word we
    /// just corrected means the correction was wrong: remember the original.
    /// Returns the newly rejected word, if any.
    @discardableResult
    mutating func deleted(bufferCountBefore: Int) -> String? {
        floor = min(floor, max(0, bufferCountBefore - 1))
        // `end` includes the boundary after the word; reaching `end - 1` deletes
        // a letter of the corrected word itself.
        guard let l = last, bufferCountBefore <= l.end - 1 else { return nil }
        last = nil
        return rejected.insert(l.original.lowercased()).inserted ? l.original.lowercased() : nil
    }

    /// The finished word (letters only, ≥ 3) before the trailing boundary in
    /// `buffer`, if it was typed entirely since the last caret jump and the
    /// author hasn't rejected correcting it.
    func candidate(in buffer: String) -> (word: String, boundary: Character)? {
        guard let boundary = buffer.last, boundary == " " || boundary == "\n" else { return nil }
        let fresh = buffer.dropFirst(min(floor, buffer.count)).dropLast()
        let word = fresh.reversed().prefix { $0 != " " && $0 != "\n" }.reversed()
        // The word must start inside the fresh run (a boundary or the jump point before it).
        guard word.count < fresh.count || floor == 0 else { return nil }
        let text = String(word)
        guard text.count >= 3, text.allSatisfy(\.isLetter), !rejected.contains(text.lowercased()) else { return nil }
        return (text, boundary)
    }

    mutating func corrected(_ original: String, to corrected: String, bufferCount: Int) {
        last = (original, corrected, bufferCount)
    }
}
