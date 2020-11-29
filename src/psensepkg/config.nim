import yaml,sequtils ,math ,algorithm ,strformat

type
  Level*     = object
    enterTemp*:  float64
    freq*:       float64
  FanConfig* = object
    info*:           string
    index*:          int
    temp*:           uint8 # when enable
    rpm*:            uint8 # fan speed


const defaultLevels = (1..4).toSeq.map(proc (x: int): Level =
  let m = float64(x) * 25
  result = Level(enterTemp: m, freq: m))

type
  Settings*  = object
    max* {. defaultVal: 0x64 .}:    uint8
    min* {. defaultVal: 0x00 .}:    uint8
    levels* {. defaultVal: defaultLevels .}:     seq[Level]
  Fan*       = object
    name*:       string
    address*:    uint8
    auto* {. defaultVal: 0x04 .}:       uint8
    manual* {. defaultVal: 0x14 .}:     uint8
    wrReg*:      uint8
    rdReg*:      uint8
    min* {. defaultVal: 0xff .}:        uint8
    max* {. defaultVal: 0x00 .}:        uint8
    levels* {. transient .}:            seq[FanConfig]
  Zone*      = object
    name*:       string
    address*:    uint8
    min* {. defaultVal: 0x00 .}:        uint8
    max* {. defaultVal: 0xff .}:        uint8
    fans* {. defaultVal: newSeq[Fan]() .}:       seq[Fan]
  Config*    = object
    name*:       string
    pollTickMs*: uint16
    reaction*:   uint8
    cmdPort*:    uint8
    dataPort*:   uint8 
    zones*:      seq[Zone]
    config*:   Settings


proc `<`(a,b: FanConfig): bool = 
  result = a.temp < b.temp

method levelConfig*(fan: Fan, temp: uint8): Option[FanConfig] {. base .} =
  var foundAt = -1
  var levels = fan.levels
  levels.sort(Ascending)
  for (index, level) in fan.levels.pairs:
    if level.temp <= temp:
      foundAt = index
    else:
      break

  if foundAt < 0:
    # continue in auto mode
    result = none[FanConfig]()
    return

  result = some[FanConfig](fan.levels[foundAt])
  

proc fanConfig(min: uint8, max:uint8, fan: ptr Fan, config: Settings): void =
  ## gerates set of calculated values per unique fan
  let zoneTempRange = int16(max) - int16(min)
  let rpmRange = int16(fan.max) - int16(fan.min)

  var tempRange = int16(config.max) - int16(config.min)
  if tempRange > zoneTempRange:
    tempRange = zoneTempRange

  let rpmPoint = float64(rpmRange) * 1e-2
  let tempPoint = float64(tempRange) * 1e-2

  var list = newSeq[FanConfig](config.levels.len)
  
  for (index, level) in config.levels.pairs:
    var rpmDirt = level.freq * rpmPoint
    var rpm:uint8
    # in case reverse values
    if rpmDirt < 0:
      rpm = uint8(floor(rpmDirt))
    else:
      rpm = uint8(round(rpmDirt))

    var tempDirt = level.enterTemp * tempPoint
    var temp: uint8
        # in case reverse values
    if tempDirt < 0:
      temp = uint8(floor(tempDirt))
    else:
      temp = uint8(round(tempDirt))

    list[index].info = fmt"L:{index+1} T:{level.enterTemp:0.1F} F:{level.freq:0.1F} ({temp:#02X} {rpm:#02X})"
    list[index].temp = temp
    list[index].rpm = rpm
    list[index].index = (index + 1)
  # save levels
  fan.levels = list

method normalize*(cfg: var Config): void {. base .} =
  for zone in cfg.zones:
    for i in 0..zone.fans.high:
      var fanPtr = zone.fans[i].unsafeAddr
      fanConfig(zone.min, zone.max, fanPtr, cfg.config)