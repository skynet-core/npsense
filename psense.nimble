import sequtils
import tables
import strutils
# Package

version       = "0.6.5"
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

task static, "Build static musl binaries":
    let dir = getCurrentDir()
    exec "docker run --rm -v " & dir & ":/home/nim/psense -it smartcoder/psense-builder:v0.1.0 bash -c 'cd /home/nim/psense && nimble build --gcc.exe:gcc --gcc.linkerexe:gcc --passL:-static -d:release --opt:size -y'"

task setup, "Install psense service":
    
    let dir = getCurrentDir()
    var 
        keys = newSeq[string]()
        vals = newSeq[string]()
    for i in countup(0, paramCount(), 1):
        let parts = paramStr(i).split(":")
        keys.add(parts[0])
        if parts.len > 1:
            vals.add(parts[1])
        else:
            vals.add("") 
    let argsTable = zip(keys,vals).toTable
    if not argsTable.contains("--configName"):
        echo "Error: --configName missed"
        quit(1)

    if argsTable.getOrDefault("--configName").strip().len == 0:
        echo "Error: --configName value is empty string"
        quit(1)

    exec selfExe() & " " & dir & "/res/install/" & hostOS & ".nims " & argsTable["--configName"]

task purge, "Removing service from system":
    let dir = getCurrentDir()
    exec selfExe() & " " & dir & "/res/uninstall/" & hostOS & ".nims"

task clean, "clean artifacts":
    exec "rm -rf psensepkg psense tests/test1 here.pid"
    echo "Done"