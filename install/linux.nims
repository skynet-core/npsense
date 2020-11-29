import os

var params = commandLineParams()
exec "sudo " & getCurrentDir() & "/install/linux.sh " & params[1]