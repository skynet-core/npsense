# Package

version       = "0.6.0"
author        = "Skynet Core"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["psense","psensepkg/cli/psensectl"]


# Dependencies

requires "nim >= 1.4.0"
requires "yaml#head"
requires "argparse >= 1.0.0"

task setup, "Install psense service":
    let dir = getCurrentDir()
    exec selfExe() & " " & dir & "/install/" & hostOS & ".nims"

task purge, "Removing service from system":
    let dir = getCurrentDir()
    exec selfExe() & " " & dir & "/install/" & hostOS & ".nims"

task clean, "clean artifacts":
    exec "rm -rf psensepkg psense tests/test1 here.pid"
    echo "Done"