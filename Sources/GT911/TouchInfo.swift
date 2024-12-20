//=== TouchInfo.swift -----------------------------------------------------===//
//
// Copyright (c) MadMachine Limited
// Licensed under MIT License
//
// Authors: Andy Liu
// Created: 12/19/2024
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

/// Represents information for a single touch point on a capacitive touchscreen.
///
/// The `TouchInfo` structure contains the essential details about a touch event,
/// including an identifier, the x and y coordinates, and the size of the touch area.
///
/// ## Overview
/// This structure is commonly used to handle touch input data from multi-touch
/// capacitive screens, providing necessary information for touch tracking and
/// gesture recognition.
///
/// ## Example
///
/// ```swift
/// let touch = TouchInfo(id: 1, x: 150, y: 300, size: 12)
/// print("Touch ID: \(touch.id), Position: (\(touch.x), \(touch.y)), Size: \(touch.size)")
/// ```
///
/// ## Topics
/// - ``id``
/// - ``x``
/// - ``y``
/// - ``size``
public struct TouchInfo {
    /// The unique identifier for the touch point.
    ///
    /// This ID is used to differentiate between multiple touch points during a multi-touch event.
    public let id: UInt8

    /// The x-coordinate of the touch point on the screen.
    ///
    /// Represents the horizontal position of the touch point, typically in pixels.
    public let x: UInt16

    /// The y-coordinate of the touch point on the screen.
    ///
    /// Represents the vertical position of the touch point, typically in pixels.
    public let y: UInt16

    /// The size of the touch point contact area.
    ///
    /// This value typically indicates the diameter or magnitude of the touch area,
    /// reflecting how large the contact is (e.g., larger for more pressure).
    public let size: UInt16
}
