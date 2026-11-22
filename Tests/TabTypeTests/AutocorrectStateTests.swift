import XCTest
@testable import TabType

final class AutocorrectStateTests: XCTestCase {
    func testFinishedWordIsACandidate() {
        let state = AutocorrectState()
        XCTAssertEqual(state.candidate(in: "hello wrld ")?.word, "wrld")
        XCTAssertNil(state.candidate(in: "hello wrld"), "no boundary yet")
        XCTAssertNil(state.candidate(in: "see e.g "), "not letters only")
        XCTAssertNil(state.candidate(in: "an "), "too short")
    }

    func testWordSpanningACaretJumpIsNeverTouched() {
        // Typed "hello wr", clicked elsewhere, typed "ld ": the buffer reads
        // "hello wrld " but the field has "ld " next to the caret — correcting
        // "wrld" would backspace 5 characters of someone else's text.
        var state = AutocorrectState()
        state.caretJumped(bufferCount: "hello wr".count)
        XCTAssertNil(state.candidate(in: "hello wrld "))
        // A whole word typed after the jump is fine again.
        XCTAssertEqual(state.candidate(in: "hello wrld teh ")?.word, "teh")
    }

    func testWordStartingExactlyAtTheJumpIsAmbiguousAndSkipped() {
        // The caret may have landed mid-word ("he|llo") — unknown, so leave it.
        var state = AutocorrectState()
        state.caretJumped(bufferCount: 6)
        XCTAssertNil(state.candidate(in: "hello wrld "))
    }

    func testBackspacingIntoACorrectionRejectsTheOriginalForGood() {
        var state = AutocorrectState()
        // "teh " → "the " (buffer "ok the ", 7 chars).
        state.corrected("teh", to: "the", bufferCount: 7)
        XCTAssertNil(state.deleted(bufferCountBefore: 7), "deleting the space alone isn't a revert")
        XCTAssertEqual(state.deleted(bufferCountBefore: 6), "teh")
        XCTAssertNil(state.candidate(in: "ok teh "), "the author's own word stays")
        XCTAssertEqual(state.candidate(in: "ok wrld ")?.word, "wrld", "other words still correct")
    }

    func testRejectionIsCaseInsensitive() {
        let state = AutocorrectState(rejected: ["nilava"])
        XCTAssertNil(state.candidate(in: "hi Nilava "))
    }

    func testTypingOnAfterACorrectionDoesNotRevertIt() {
        var state = AutocorrectState()
        state.corrected("teh", to: "the", bufferCount: 7)
        // More words typed, then a typo fixed two words later: still past the correction.
        XCTAssertNil(state.deleted(bufferCountBefore: 15))
        XCTAssertTrue(state.rejected.isEmpty)
    }

    func testCaretJumpForgetsThePendingCorrection() {
        var state = AutocorrectState()
        state.corrected("teh", to: "the", bufferCount: 7)
        state.caretJumped(bufferCount: 7)
        XCTAssertNil(state.deleted(bufferCountBefore: 6), "backspacing elsewhere isn't a revert")
    }

    func testDeletingBeforeTheJumpLowersTheFloor() {
        var state = AutocorrectState()
        state.caretJumped(bufferCount: 5)          // buffer "hello"
        state.deleted(bufferCountBefore: 5)        // buffer "hell"
        XCTAssertEqual(state.floor, 4)
    }
}
