# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.
import argparse, os, posix, strutils, strformat ,parseutils
import tables, bitops, math, yaml ,selectors, times

import psensepkg/port
import psensepkg/config

proc killService(pid: uint): void = 
  discard kill(cint(pid), SIGKILL)
  var res: cint
  discard waitpid(Pid(pid), res, bitor(WUNTRACED, WCONTINUED))

when isMainModule:
  let pid = getCurrentProcessId()
  var p = newParser("psense"):
    option("-c","--config", default = some("config.yaml"), help = "config file's path")
    option("-p","--pidfile",default = some("/run/psense.pid"), help = "pifile's path")
    flag("-f","--force", help = "force daemon start")

  let opts = p.parse(commandLineParams())
  if not os.fileExists(opts.config):
    stderr.writeLine(fmt"file {opts.config} doesn't exist")
    quit(1)
  if os.fileExists(opts.pidfile):
    if not opts.force:
      stderr.writeLine(fmt"pidfile {opts.pidfile} alredy exists, please kill owner process and remove it before or use --force flag")
      quit(1)
    let raw = readFile(opts.pidfile)
    let spid = parseUInt(raw.strip())
    killService(spid)
    discard truncate(opts.pidfile,0)
  
  # here we can lock
  writeFile(opts.pidfile, $pid & "\n")
  let s = newFileStream(opts.config,fmRead)
  var cfg = Config()
  load(s, cfg)
  s.close()
  cfg.normalize()
  # now we have config read
  
  # register some events handlers
  let 
    sel = newSelector[int]()
    sKill = sel.registerSignal(SIGKILL, 0)
    sTerm = sel.registerSignal(SIGTERM, 0)
    sHup = sel.registerSignal(SIGHUP, 0)
    sPause = sel.registerSignal(SIGTSTP, 0)
    sCont = sel.registerSignal(SIGCONT, 0)
    ctrl = newPort(cfg.cmdPort, cfg.dataPort)

  
  var
    sTime = sel.registerTimer(1000, oneshot = false,0) # once per second 
    zones = newSeq[array[2,int]](cfg.zones.len)
    levels = newTable[int,int]()
  while true:
    for ev in sel.select(-1):
        let timeStr = now().format("dd-MM-yyyy HH:mm:ss")
        if ev.fd == sHup or ev.fd == sCont:
            # reload config in main loop and send update to worker
            let s = newFileStream(opts.config, fmRead)
            load(s, cfg)
            s.close()
            cfg.normalize()
            # awake from sleep
            if ev.fd == sCont:
              sTime = sel.registerTimer(1000, oneshot = false,0)
              stderr.writeLine("SIGCONT received. Continue watching ...")
            else:
              stderr.writeLine("SIGHUP received. Updating configuration ...")

        if ev.fd == sPause or ev.fd == sTerm or ev.fd == sKill:
          sel.unregister(sTime)
          for (index, zone) in cfg.zones.pairs:
              zones[index][1] = 0
              zones[index][0] = 0
              for (n, fan) in zone.fans.pairs:
                let fanKey = index * 10 + n
                ctrl.send(fan.address, fan.auto)
                levels[fanKey] = 0
          if ev.fd == sPause:
            stderr.writeLine("SIGTSTP received. Going idle ...")
          elif ev.fd == sTerm:
            stderr.writeLine("SIGTERM received. Quiting ...")
            quit(0)
          else:
            stderr.writeLine("SIGTERM received. Quiting ...")
            quit(0)

        if ev.fd == sTime:
            ## iterate through zones and compare temp with level bounds
            for (index, zone) in cfg.zones.pairs:
              let temp = ctrl.recv(zone.address)
              zones[index][1] += int(temp)
              zones[index][0] += 1
              let zoneAvg = round(zones[index][1]/zones[index][0])
              # reset at the and
              if zones[index][0] > 5:
                # we have average temp for this zone, lets configure fans based on it
                for (n, fan) in zone.fans.pairs:
                  let fanKey = index * 10 + n # zone multiplied by 10 as higher range
                  # do we need to enable this fan?
                  let cfg: Option[FanConfig] = fan.levelConfig(uint8(zoneAvg))
                  if cfg.isSome():
                    let prevLev = levels.getOrDefault(fanKey)

                    if prevLev != cfg.unsafeGet.index:
                      if prevLev == 0:
                        ctrl.send(fan.address, fan.manual)
                      
                      ctrl.send(fan.wrReg, cfg.unsafeGet.rpm)
                      stderr.writeLine(fmt"{timeStr}: [{zone.name} {fan.name}] -> [ {cfg.unsafeGet.info} ]")
                      levels[fanKey] = cfg.unsafeGet.index
                  else:
                    ctrl.send(fan.address, fan.auto)
                    stderr.writeLine(fmt"{timeStr}: [{zone.name} {fan.name}] -> [ auto ]")
                    levels[fanKey] = 0

                zones[index][1] = 0
                zones[index][0] = 0
  
  stderr.writeLine("quit unexpectedly...")
  quit(1)