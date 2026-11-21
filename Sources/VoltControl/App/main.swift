#if !arch(arm64)
#error("VoltControl поддерживает только Apple Silicon")
#endif

import AppKit

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-icon" {
    let outputPath = CommandLine.arguments[2]
    guard let data = AppIconGenerator.pngData(size: 1024) else {
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: outputPath))
        exit(0)
    } catch {
        fputs("Failed to write icon: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
