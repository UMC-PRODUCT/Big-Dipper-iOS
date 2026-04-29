// Masks a square PNG into the macOS app-icon squircle with Apple's standard
// 100/1024 padding. Outputs a 1024x1024 PNG.
//
// Usage: swift scripts/mask-icon.swift <input.png> <output.png>

import AppKit

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: mask-icon.swift <in.png> <out.png>\n".utf8))
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: input) else {
    FileHandle.standardError.write(Data("failed to load \(input.path)\n".utf8))
    exit(1)
}

let canvas: CGFloat = 1024
let inset: CGFloat = 100              // Apple's macOS template padding
let innerSize = canvas - 2 * inset    // 824
let cornerRadius = innerSize * 0.2237 // continuous-curve approximation

// Center-crop the source to a square so non-square inputs aren't stretched.
let sourceSize = source.size
let squareSide = min(sourceSize.width, sourceSize.height)
let cropRect = NSRect(
    x: (sourceSize.width - squareSide) / 2,
    y: (sourceSize.height - squareSide) / 2,
    width: squareSide,
    height: squareSide
)

let result = NSImage(size: NSSize(width: canvas, height: canvas))
result.lockFocus()

NSColor.clear.set()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

let innerRect = NSRect(x: inset, y: inset, width: innerSize, height: innerSize)
let path = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius, yRadius: cornerRadius)
path.addClip()

source.draw(in: innerRect, from: cropRect, operation: .copy, fraction: 1.0)

result.unlockFocus()

guard let tiff = result.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
    exit(1)
}

try png.write(to: output)
