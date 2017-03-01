import stopwatch, random
import briefly

proc main() =
  const
    width = 1_000_000_000
    ops = 10000
  echo "Initialization starting"
  randomize(12435)
  var
    b = bits(width)
    indicesRank = newSeq[int]()
    indicesSelect = newSeq[int]()
    sw = stopwatch()

  for i in 0 .. <  width:
    if random(2) == 0:
      incl(b, i)

  for _ in 0 .. < ops:
    indicesRank.add(random(width))
    indicesSelect.add(random(width div 3))

  let r = rrr(b)
  echo "Initialization done"

  sw.start()
  for i in indicesRank:
    discard r.rank(i)
  sw.stop()

  echo "We have required ", sw.secs(), " seconds to compute ", ops, " ranks."

  sw.start()
  for i in indicesSelect:
    discard r.select(i)
  sw.stop()

  echo "We have required ", sw.secs(), " seconds to compute ", ops, " selects."

when isMainModule:
  main()