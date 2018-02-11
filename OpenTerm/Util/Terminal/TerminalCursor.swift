//
//  TerminalBuffer.swift
//  OpenTerm
//
//  Created by Ian McDowell on 2/9/18.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import UIKit

/// The cursor represents an x / y position in the terminal, where text is inserted as it comes in.
/// This implementation stores 3 values, x, y, and an offset. It's important that the developer synchronize
/// updates to the cursor with updates to the underlying storage (TerminalBuffer / NSTextStorage)
struct TerminalCursor {
	/// 0-based location in the current line
	private(set) var x: Int

	/// 0-based row in the current viewport
	private(set) var y: Int

	/// 0-based offset in the entire storage, must stay in sync with x/y position.
	private(set) var offset: Int

	/// Convenience zero (top left) value.
	static let zero = TerminalCursor(x: 0, y: 0, offset: 0)

	enum Direction {
		case up, down, left, right, beginningOfLine, endOfString
	}
	enum Axis {
		case x, y
	}

	/// Each row that the cursor moves through is separated by newlines.
	private let newlineCharacterSet = CharacterSet.newlines

	/// Move the cursor in the given direction inside the given storage.
	/// If it can't move any more, it does nothing.
	mutating func move(_ direction: Direction, in storage: NSTextStorage) {
		dispatchPrecondition(condition: .onQueue(.main))

		let string = storage.string
		let offset = string.index(string.startIndex, offsetBy: self.offset)
		switch direction {
		case .up:
			fatalError("Not implemented")
		case .down:
			let nextNewLine = self.indexAfterNextNewline(from: offset, in: string)

			// Calculate our new offset. If it goes past the end, this will be nil, and we do nothing
			if let newOffset = string.index(nextNewLine, offsetBy: x, limitedBy: string.endIndex) {
				let distance = string.distance(from: string.startIndex, to: newOffset)
				if distance != self.offset {
					// Only move if offset changed.
					self.offset = distance
					self.y += 1
				}
			}
		case .left:
			let previousNewLine = self.indexAfterPreviousNewline(from: offset, in: string)
			// Only move left until we hit a newline
			if offset > previousNewLine {
				self.x -= 1
				self.offset -= 1
			}
		case .right:
			let nextNewLine = self.indexOfNextNewline(from: offset, in: string)
			// Only move right until we hit a newline
			if offset < nextNewLine {
				self.x += 1
				self.offset += 1
			}
		case .beginningOfLine:
			self.x = 0
			self.offset = string.distance(from: string.startIndex, to: self.indexAfterPreviousNewline(from: offset, in: string))
		case .endOfString:
			let components = string.components(separatedBy: newlineCharacterSet)
			self.offset = string.count
			self.y = components.count - 1
			self.x = components.last?.count ?? 0
		}
	}

	/// Set the position of the cursor on the given axis.
	mutating func set(_ axis: Axis, to position: Int, in storage: NSTextStorage) {
		dispatchPrecondition(condition: .onQueue(.main))

		let string = storage.string
		let offset = string.index(string.startIndex, offsetBy: self.offset)

		switch axis {
		case .x:
			let beginningOfLine = self.indexAfterPreviousNewline(from: offset, in: string)
			let endOfLine = self.indexOfNextNewline(from: offset, in: string)
			let lineLength = string.distance(from: beginningOfLine, to: endOfLine)
			if position <= lineLength {
				self.x = position
				self.offset = string.distance(from: string.startIndex, to: string.index(beginningOfLine, offsetBy: position))
			}
		case .y:
			fatalError("Setting the y axis' position is not currently supported.")
		}
	}

	/// How far is the current x position from the next newline character?
	func distanceToEndOfLine(in storage: NSTextStorage) -> Int {
		let string = storage.string
		let offset = string.index(string.startIndex, offsetBy: self.offset)
		let index = self.indexOfNextNewline(from: offset, in: string)
		let distance = string.distance(from: offset, to: index)
		return distance
	}

	private func indexAfterPreviousNewline(from currentPosition: String.Index, in string: String) -> String.Index {
		if let range = rangeOfPreviousNewline(from: currentPosition, in: string) {
			return range.upperBound
		}
		// If none was found, return the beginning of the string
		return string.startIndex
	}

	private func indexOfNextNewline(from currentPosition: String.Index, in string: String) -> String.Index {
		if let range = rangeOfNextNewline(from: currentPosition, in: string) {
			return range.lowerBound
		}
		// If none was found, return the end of the string
		return string.endIndex
	}

	private func indexAfterNextNewline(from currentPosition: String.Index, in string: String) -> String.Index {
		if let range = rangeOfNextNewline(from: currentPosition, in: string) {
			return range.upperBound
		}
		// If none was found, return the end of the string
		return string.endIndex
	}

	private func rangeOfPreviousNewline(from currentPosition: String.Index, in string: String) -> Range<String.Index>? {
		// Find the next newline, starting at the current position and going backwards.
		return string.rangeOfCharacter(from: newlineCharacterSet, options: .backwards, range: string.startIndex..<currentPosition)
	}

	private func rangeOfNextNewline(from currentPosition: String.Index, in string: String) -> Range<String.Index>? {
		// Find the next newline, starting at current position and going forwards.
		return string.rangeOfCharacter(from: newlineCharacterSet, options: [], range: currentPosition..<string.endIndex)
	}
}
