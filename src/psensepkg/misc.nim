import argparse, os, posix, strutils, strformat ,parseutils
import tables, bitops, math, yaml ,selectors, times

import ./config

proc loadConfig*(path: string): Config = 
    let s = newFileStream(path,fmRead)
    result = Config()
    load(s, result)
    s.close()
    result.normalize()