#!/usr/bin/env python3
"""Render the existing SwiftUI skyline for Skip, whose Canvas API is unavailable."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "Sources/Conjugation/Views/Components.swift").read_text()
view = source[source.index("struct ParisSkyline: View"):source.index("\nextension View")]
# Use the original Canvas branch on macOS.
output = root / "Sources/Conjugation/Resources/Module.xcassets/ParisSkyline.imageset/ParisSkyline.png"
script = "import SwiftUI\nimport AppKit\nimport Foundation\n" + view + """
@MainActor func render() throws {
    let renderer = ImageRenderer(content: ParisSkyline().frame(width: 440, height: 320))
    renderer.scale = 3
    let bitmap = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
try MainActor.assumeIsolated { try render() }
"""
with tempfile.TemporaryDirectory(prefix="french-verbs-skyline-") as temporary:
    path = Path(temporary) / "render.swift"
    path.write_text(script)
    subprocess.run(["/usr/bin/swift", str(path), str(output)], check=True)
print(output)
