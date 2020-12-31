# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.
import argparse, os, strutils, nim_smbios, selectors, times, posix, tables, db_sqlite, strformat
import nsensepkg/[cli, misc, state, port]
import nsensepkg/config as cfg


when isMainModule:
  let
    wd = getCurrentDir()
    app = parseCli(commandLineParams()) 
    pid = getCurrentProcessId()
    dbFile = dbFilePath(wd)
    pidFile = joinPath(wd, app.pidfile)
  # check another instances
  if fileExists(pidFile):
    if not app.force:
      quit("another instance of the service seems is running, please kill or pass --force option", -1)
    else:
      let oldPid = readPid(pidFile)
      killService(oldPid)
      discard truncate(pidFile, 0)
  # save new pid
  writeFile(pidFile, $pid)
  # read bios model info
  var
    config: Config
    client: DbConn
    configFile = configFilePath(wd) 
    smbParser = initParser()
  let 
    result = smbParser.parseTable()
    opt = result.structs(dtSystem.uint8)
  
  if opt.isNone or opt.unsafeGet.len < 1:
    quit("failed to read system information", -1)
  let 
    sysInfo =  cast[SystemInfo](opt.unsafeGet[0])
    model        = sysInfo.manufacturer & " " & sysInfo.productName

  client = open(dbFile, "", "", "")
  # TODO: read config from db file


  if not config.ready():
    # check if config for current model exists or /etc/config(.yml*) exists
    configFile = resolveConfig(wd, model, configFile)
    config = if configFile.len > 0:
      loadConfig(configFile)
    else:
      defaultConfig(name = model)

  echo config

  let 
    sel = newSelector[int]()
    killFd = sel.registerSignal(SIGKILL, 0)
    termFd = sel.registerSignal(SIGTERM, 0)
    hupFd = sel.registerSignal(SIGHUP, 0)
    pauseFd = sel.registerSignal(SIGTSTP, 0)
    contFd = sel.registerSignal(SIGCONT, 0)

  var 
    ctrl: Port
    timerFd = sel.registerTimer(int(config.pollTickMs), oneshot = false,0) # once per second 
    zones   = initZones(config.zones)

  let 
    loadAndReset = proc(): void =
      if configFile.len > 0:
        config = loadConfig(configFile)
      resetZonesDeep(zones)
      if config.ready():
        ctrl = newPort(config.cmdPort, config.dataPort)
        if sel.contains(timerFd):
          sel.unregister(timerFd)
        timerFd = sel.registerTimer(int(config.pollTickMs), oneshot = false, 0)
    unregisterTimerAndReset = proc(): void = 
      if sel.contains(timerFd):
        sel.unregister(timerFd)
      resetZonesDeep(zones)

  let handlerSwitch = {
    hupFd: proc(timeStr: string): void =
      stderr.writeLine(fmt"{timeStr}: SIGHUP received. Updating configuration ...")
      loadAndReset()
    ,
    contFd: proc(timeStr: string): void =
      stderr.writeLine(fmt"{timeStr}: SIGCONT received. Continue watching ...")
      loadAndReset()
    ,
    pauseFd: proc(timeStr: string): void =
      unregisterTimerAndReset()
      stderr.writeLine(fmt"{timeStr}: SIGTSTP received. Going idle ...")
    ,
    timerFd: proc(timeStr: string): void =
      if not config.ready():
        unregisterTimerAndReset()
        return
      ## iterate through zones and compare temp with level bounds
      for (i, zone) in config.zones.pairs:
        var state = zones[i]
        state.currentTemp = ctrl.recv(zone.address)
        let avgTemp = state.averageTemp
        if state.ticks > int(config.reaction):
          for (j, fan) in zone.fans.pairs:
            #do we need to enable this fan?
            let prevLevel = state.fanLevels[j]
            let cfg: Option[FanConfig] = fan.levelConfig(avgTemp)
            if cfg.isSome():
              if prevLevel != cfg.unsafeGet.index:
                if prevLevel < 0:
                  ctrl.send(fan.address, fan.manual)
                ctrl.send(fan.wrReg, cfg.unsafeGet.rpm)
                state.fanLevels[j] = cfg.unsafeGet.index
                stderr.writeLine(fmt"{timeStr}: [{zone.name} {fan.name}] -> [ {cfg.unsafeGet.info} ]")
            else:
                if prevLevel > 0:
                  ctrl.send(fan.address, fan.auto)
                  stderr.writeLine(fmt"{timeStr}: [{zone.name} {fan.name}] -> [ auto ]")
                state.fanLevels[j] = -1
          state.reset()
    ,
    termFd: proc(timeStr: string): void =
      unregisterTimerAndReset()
      stderr.writeLine(fmt"{timeStr}: SIGTERM received. Quiting ...")
      quit(0)
    ,
    killFd: proc(timeStr: string): void =
      unregisterTimerAndReset()
      stderr.writeLine(fmt"{timeStr}: SIGKILL received. Quiting ...")
      quit(1)
    ,
  }.toTable

  if config.ready():
    ctrl = newPort(config.cmdPort, config.dataPort)

  while true:
    for ev in sel.select(-1):
      if handlerSwitch.contains(ev.fd):
        let timeStr = now().format("dd-MM-yyyy HH:mm:ss")
        handlerSwitch[ev.fd](timeStr)