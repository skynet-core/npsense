import argparse, os, strutils ,parseutils
import tables, yaml

import ./config

proc loadConfig*(path: string): Config = 
    let s = newFileStream(path,fmRead)
    result = Config()
    load(s, result)
    s.close()
    result.normalize()