function initAdTracking(player, livePass, session = invalid)
  this = {}

  this["_player"] = player
  this["_livePass"] = livePass
  this["_podIndex"] = 0
  this["_session"] = session
  this["_adType"] = ""

  this["adTrackingMode"] = {
    "BASIC": 0,
    "AD_BREAK": 1,
    "AD_EXPERIENCE": 2
  }

  this["onAdBreakStarted"] = sub()
    adBreak = m._player.callFunc(m._player.BitmovinFunctions.AD_LIST)[m._podIndex]
    duration = 0

    for each ad in adBreak.ads
      duration += ad.duration
    end for

    m._adType = m._mapAdPosition(adBreak, duration)

    m._podIndex++

    podInfo = {
      "podDuration": StrI(duration),
      "podPosition": m._adType,
      "podIndex": StrI(m._podIndex),
      "absoluteIndex": "1" ' Always reporting 1 is sufficient if we can't reliably track it
    }
    m._livePass.sendSessionEvent(m._session, "Conviva.PodStart", podInfo)
  end sub

  this["onAdBreakFinished"] = sub()
    podInfo = {
      "podPosition": m._adType,
      "podIndex": StrI(m._podIndex),
      "absoluteIndex": "1"
    }
    m._livePass.sendSessionEvent(m._session, "Conviva.PodEnd", podInfo)
  end sub

  this["updateSession"] = sub(session)
    m._session = session
  end sub

  this["_mapAdPosition"] = function(adBreak, duration)
    if adBreak.scheduleTime = 0
      adType = "Pre-roll"
    else if ((adBreak.scheduleTime + duration) >= m._player.findNode("MainVideo").duration)
      adType = "Post-roll"
    else
      adType = "Mid-roll"
    end if

    return adType
  end function

  return this
end function
