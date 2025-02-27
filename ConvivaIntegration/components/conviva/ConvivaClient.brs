' ConvivaClient
' authors: Kedar Marsada <kmarsada@conviva.com>, Mayank Rastogi <mrastogi@conviva.com>,  Happy Singh <hasingh@conviva.com>
'

'==== Public interface to the ConvivaLivePass library ====
' The code below should be used in the integrations.
'==== Public interface to the ConvivaLivePass library ====

'''
''' ConvivaClient is a singleton that returns ConvivaClientInstance
'''
function ConvivaClient(settings as object)
    globalAA = getGlobalAA()

    if globalAA.ConvivaClient = invalid
    	globalAA.ConvivaClient = ConvivaClientInstance(settings)
    end if

    return globalAA.ConvivaClient
end function

'''
''' ConvivaClient class
''' @Params: settings containing gatewayUrl, customerKey
'''
function ConvivaClientInstance(settings as object)
	self = {}
	self.settings = settings

  'Ad technology type'
	self.AD_TYPE = {
		CLIENT_SIDE: "Client Side",
		SERVER_SIDE: "Server Side"
	}

  ' Player states'
	self.PLAYER_STATE = {
        STOPPED:        "1",
        BUFFERING:      "6",
        PLAYING:        "3",
        PAUSED:        "12"
	}

  'Error severity'
  self.ERROR_SEVERITY = {
    WARNING: false,
    FATAL: true
  }

  self.VideoNodeIdentifier = createObject("RoSGNode","ContentNode")

  ' Keeps track of all video nodes currently being monitored along with their corresponding Conviva task instances
	self.monitors = []

  ' Utility function to check if videonode is already being monitored & stored
	self.isVideoExists = function(videoNode as object)
		self = m
		if videoNode <> Invalid
      for each monitor in self.monitors
      	if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
      		return true
      	end if
      end for
    end if
  	return false
	end function

  'Utility function to get corresponding conviva task for a given video node
	self.getConvivaTask = function(videoNode as object)
	self = m
    if videoNode <> invalid
		  for each monitor in self.monitors
      	if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
      		return monitor.convivaTask
      	end if
    	end for
    end if
  	return invalid
	end function

  '
  ' monitorVideoNode : Creates conviva task, registers for listeners and starts Conviva session monitoring
  ' @params: videonode and contentinfo objects
  ' contentInfo is an associative array consisting of assetname, streamUrl, .. etc metadata about the video
  '
	self.monitorVideoNode = function(videoNode as object, contentInfo as object)
		self = m
        'Check if videoNode is already being monitored
        if self.isVideoExists(videoNode)
          return invalid
        end if

        'Create Conviva Task
        convivaTask = createObject("roSGNode", "ConvivaPlayerMonitor")
        if videoNode.isSubtype("Video")
          convivaTask.callFunc("monitorNode", videoNode, contentInfo)
        else
          convivaTask.callFunc("monitorNode", invalid, contentInfo)
        end if

        convivaTask.gatewayUrl = self.settings.gatewayUrl
        convivaTask.customerKey = self.settings.customerKey

        if self.settings.disableErrorReporting <> invalid
          convivaTask.disableErrorReporting = self.settings.disableErrorReporting
        end if

        convivaTask.control = "RUN"
        if videoNode <> Invalid and videoNode.isSubtype("Video")
          videoNode.appendChild(convivaTask)
        end if
        'Append task to videoNode as child.
        monitor = CreateObject("roAssociativeArray")
        monitor.videoNode = videoNode
        monitor.convivaTask = convivaTask

        'store videoNode
        self.monitors.push(monitor)
        self.log(videoNode, "ConvivaClient monitorVideoNode")
	end function

  ' To associate a videoNode to an existing monitoring session
  ' To use this API, monitorVideoNode should hav been called with a videonodeidentifier earlier.
  self.associateVideoNode = function (videoNode as object)
    self = m
    'Check if videoNode is already being monitored
    if self.isVideoExists(videoNode)
      return invalid
    end if

    convivaTask = self.getConvivaTask(self.VideoNodeIdentifier)
    if videoNode <> Invalid and videoNode.isSubtype("Video")

      ' DE-6578 associate video node issue - Video node was not getting updated to latest
      metadata = {}
      metadata.type = "ConvivaUpdateVideoNode"
      metadata.videoNode = videoNode
      convivaTask.callFunc("dispatchEvent", metadata)

      videoNode.appendChild(convivaTask)
    end if
    'Append task to videoNode as child.
    monitor = CreateObject("roAssociativeArray")
    monitor.videoNode = videoNode
    monitor.convivaTask = convivaTask

    'store videoNode
    self.monitors.clear()
    self.monitors.push(monitor)
    self.log(videoNode, "ConvivaClient associateVideoNode")
  end function
  '
  ' To register existing conviva task with client instance to avoid client from recreating a task for monitoring purposes.
  ' Mainly used when LivePass APIs are used instead of monitorVideoNode for experience insights integrations.
  ' Conviva client reuses the task to perform Ad insights monitoring using client APIs
  '
  ' @params: videonode: to which conviva task is created
  ' convivaTask: existing conviva task created in applications for monitoring purposes.
  '
	self.configureExistingTask = function(videoNode as object, convivaTask as object)
		self = m

		if self.isVideoExists(videoNode)
			return invalid
		end if
		'To use existing task, append task to video node as child & save it
		videoNode.appendChild(convivaTask)
		' add to monitors
        monitor = CreateObject("roAssociativeArray")
        monitor.videoNode = videoNode
        monitor.convivaTask = convivaTask

        'store videoNode
        self.monitors.push(monitor)
	end function

  '
  ' To be used only when you want to end monitoring abruptly - Like click of back button during video playback and at the end of playback
  self.endMonitoring = function(videoNode as object)
    self = m
    if self.isVideoExists(videoNode) = false
      return invalid
    end if

    self.log(videoNode, "ConvivaClient endMonitoring")
	convivaTask = self.getConvivaTask(videoNode)
	if convivaTask <> invalid
		metadata = {}
		metadata.type = "ConvivaCleanupSession"
		convivaTask.callFunc("dispatchEvent", metadata)
	end if
    index=0
    for each monitor in self.monitors
      if monitor.videoNode <> invalid and monitor.videoNode.isSameNode(videoNode)
        self.monitors.delete(index)
      end if
      index = index + 1
    end for
  end function

  ' Updates content metadata to a content session for a given video node.
	self.setOrUpdateContentInfo = function(videoNode as object, contentInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient setOrUpdateContentInfo")
        if self.isVideoExists(videoNode) = false
        return invalid
        end if

		convivaTask = self.getConvivaTask(videoNode)
		if convivaTask <> invalid
			metadata = contentInfo
			metadata.type = "ConvivaUpdateContentMetadata"
			convivaTask.callFunc("dispatchEvent", metadata)
		end if

	end function

  ' Reports custom error to content session if it exists
  ' Yet to test reporting error when session does not exist
	self.reportContentError = function(videoNode as object, errorMessage as dynamic, severity as boolean)
        self = m
        self.log(videoNode, "ConvivaClient reportContentError")
        if self.isVideoExists(videoNode)
            convivaTask = self.getConvivaTask(videoNode)
            if convivaTask <> invalid
                contentError = {}
                contentError.type = "ConvivaContentError"
                contentError.message = errorMessage
                contentError.severity = severity
                convivaTask.callFunc("dispatchEvent", contentError)
            end if
        end if
    end function

  ' Reports custom event to a content session
	self.reportContentPlayerEvent = function(videoNode as object, eventType as dynamic, eventDetail as object)
        self=m
        self.log(videoNode, "ConvivaClient reportContentPlayerEvent")
		if self.isVideoExists(videoNode)
            convivaTask = self.getConvivaTask(videoNode)
            if convivaTask <> invalid
                contentEvent = {}
                contentEvent.type = "ConvivaContentEvent"
                contentEvent.eventType = eventType
                contentEvent.eventDetail = eventDetail
                convivaTask.callFunc("dispatchEvent", contentEvent)
            end if
        end if
	end function

  ' Pauses monitoring a given video node. Moves content session to NOT_MONITORED state
	self.setContentPauseMonitoring = function(videoNode as object)
        self=m
        self.log(videoNode, "ConvivaClient setContentPauseMonitoring")
		if self.isVideoExists(videoNode)
  		convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			contentEvent = {}
  			contentEvent.type = "ConvivaContentPauseMonitor"
  			convivaTask.callFunc("dispatchEvent", contentEvent)
  		end if
    end if
	end function

  ' Resumes monitoring a given video node. Moves content session into MONITORED state'
	self.setContentResumeMonitoring = function(videoNode as object)
        self=m
        self.log(videoNode, "ConvivaClient setContentResumeMonitoring")
		if self.isVideoExists(videoNode)
  		convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			contentEvent = {}
  			contentEvent.type = "ConvivaContentResumeMonitor"
  			convivaTask.callFunc("dispatchEvent", contentEvent)
  		end if
    end if
	end function

  ' For a given video node that handles content playback, report ad "loaded" event.
  ' Creates an ad session associating with the content session that videonode is responsible for
  ' Keeps ad session in BUFFERING state
  ' Optional call. Need not be called if ad manager does not expose ad "loaded" event
	self.reportAdLoaded = function(videoNode as object, adInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient reportAdLoaded")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = adInfo
  			adEvent.type = "ConvivaAdLoaded"
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
  end function

  ' For a given video node that handles content playback, report ad "start" / "impression" events or similar
  ' Creates an ad session associating with the content session that videonode is responsible for
  ' Keeps ad session in PLAYING state
  self.reportAdStart = function(videoNode as object, adInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient reportAdStart")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = adInfo
  			adEvent.type = "ConvivaAdStart"
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
  end function

  ' Closes an ad session if it exists
  self.reportAdEnded = function(videoNode as object, adInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient reportAdEnded")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = adInfo
  			adEvent.type = "ConvivaAdComplete"
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
  end function

  ' Reports an ad skip to the session if it exists
  self.reportAdSkipped = function(videoNode as object, adInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient reportAdSkipped")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = adInfo
  			adEvent.type = "ConvivaAdSkip"
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
  end function

  ' Updates ad metadata for an ad session on a given videonode
  self.setOrUpdateAdInfo = function(videoNode as object, contentInfo as object)
        self = m
        self.log(videoNode, "ConvivaClient setOrUpdateAdInfo")
		if self.isVideoExists(videoNode) = false
			return invalid
		end if

		convivaTask = self.getConvivaTask(videoNode)
		if convivaTask <> invalid
			metadata = contentInfo
			metadata.type = "ConvivaUpdateAdMetadata"
			convivaTask.callFunc("dispatchEvent", metadata)
		end if
	end function

  ' For a given video node that handles content playback, report ad playback or load "error"
	self.reportAdError = function(videoNode as object, errorMessage as string, severity as boolean)
        self=m
        self.log(videoNode, "ConvivaClient reportAdError")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = {}
        if severity
          adEvent.severity = self.ERROR_SEVERITY.FATAL
        else
          adEvent.severity = self.ERROR_SEVERITY.WARNING
        end if

        adEvent.type = "ConvivaAdError"
        adEvent.errorMessage = errorMessage
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
	end function

  ' For a given video node that handles content playback, report a custom event to ad session
	self.reportAdPlayerEvent = function(videoNode as object, eventType as string, eventDetail as object)
        self=m
        self.log(videoNode, "ConvivaClient reportAdPlayerEvent")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = {}
  			adEvent.type = "ConvivaAdEvent"
        adEvent.eventType = eventType
        adEvent.eventDetail = eventDetail
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
	end function

  ' Report ad break started to content sessions
  ' If adType is client side, the API takes care of calling detachStreamer & adStart LivePass APIs
  ' Report Conviva.PodStart custom event with adBreakInfo to content session'
	self.reportAdBreakStarted = function(videoNode as object, adType as string, adBreakInfo as object)
        self=m
        self.log(videoNode, "ConvivaClient reportAdBreakStarted")
		if self.isVideoExists(videoNode)
    	convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = adBreakInfo
  			adEvent.type = "ConvivaPodStart"
        adEvent.adType = adType
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
	end function

  ' Report ad break ended to content sessions
  ' If adType is client side, the API takes care of calling attachStreamer & adend LivePass APIs
  ' Report Conviva.PodEnd custom event with adBreakInfo to content session'
	self.reportAdBreakEnded = function(videoNode as object, adType as string, adBreakInfo as object)
        self=m
        self.log(videoNode, "ConvivaClient reportAdBreakEnded")
		if self.isVideoExists(videoNode)
  		convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid and adBreakInfo <> invalid
  			adEvent = adBreakInfo
  			adEvent.type = "ConvivaPodEnd"
        adEvent.adType = adType
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
	end function

  ' TBD - incomplete implementation - Will never be used. Created the API to keep it consistent across all platforms
	self.reportPlayerState = function( videoNode as object, playerState as string )
        self=m
        self.log(videoNode, "ConvivaClient reportPlayerState")
		return invalid
	end function

  ' Reports a play state to ad session that is being handled by the given videoNode
	self.reportAdPlayerState = function( videoNode as object, playerState as string )
        self=m
        self.log(videoNode, "ConvivaClient reportAdPlayerState")
		if self.isVideoExists(videoNode)
  		convivaTask = self.getConvivaTask(videoNode)
  		if convivaTask <> invalid
  			adEvent = {}
  			adEvent.playerState = playerState
  			adEvent.type = "ConvivaAdPlayerState"
  			convivaTask.callFunc("dispatchEvent", adEvent)
  		end if
    end if
	end function

  ' Reports current playing bitrate to content session. This API must be used if auto-detection by library fails
	self.reportPlayerBitrate = function(videoNode as object, bitrate as integer)
    self=m
    self.log(videoNode, "ConvivaClient reportPlayerBitrate")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.bitrate = bitrate
      event.type = "ConvivaContentBitrate"
      convivaTask.callFunc("dispatchEvent", event)
    end if
	end function

  ' Reports average bandwidth as available from manifest to content session. This API must be used always if average bandwidth value is available from application. Auto-collection is not possible
	self.reportPlayerAverageBitrate = function(videoNode as object, avgbitrate as integer)
    self=m
    self.log(videoNode, "ConvivaClient reportPlayerAverageBitrate")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.avgbitrate = avgbitrate
      event.type = "ConvivaContentAverageBitrate"
      convivaTask.callFunc("dispatchEvent", event)
    end if
	end function

  ' Reports current playing bitrate to ad session.
	self.reportAdPlayerBitrate = function(videoNode as object, bitrate as integer)
        self=m
        self.log(videoNode, "ConvivaClient reportAdPlayerBitrate")
		convivaTask = self.getConvivaTask(videoNode)
		if convivaTask <> invalid
			adEvent = {}
			adEvent.bitrate = bitrate
			adEvent.type = "ConvivaAdBitrate"
			convivaTask.callFunc("dispatchEvent", adEvent)
		end if
	end function

  ' Reports to content session that seek start is detected
	self.reportSeekStarted = function( videoNode as object, seekToPosMs as integer)
        self=m
        self.log(videoNode, "ConvivaClient reportSeekStarted")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid
        contentEvent = {}
        contentEvent.seekPos = seekToPosMs
        contentEvent.type = "ConvivaContentSeekStart"
        convivaTask.callFunc("dispatchEvent", contentEvent)
        end if
	end function

  ' Reports to content session that seek end is detected
	self.reportSeekEnd = function(videoNode as object)
        self=m
        self.log(videoNode, "ConvivaClient reportSeekEnd")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid
        contentEvent = {}
        contentEvent.type = "ConvivaContentSeekEnd"
        convivaTask.callFunc("dispatchEvent", contentEvent)
        end if
	end function

  ' TBD - Incomplete implementation
  ' Reports a custom event to a global session
	self.reportAppEvent = function(videoNode as object, eventType as string, eventDetail as object)
        self=m
        self.log(videoNode, "ConvivaClient reportAppEvent")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid
            globalEvent = {}
            globalEvent.type = "ConvivaGlobalEvent"
            globalEvent.eventType = eventType
            globalEvent.eventDetail = eventDetail
            convivaTask.callFunc("dispatchEvent", globalEvent)
        end if
    end function

  ' Reports Audio Language change content session. This API must be used if Audio Language value is available from application.
	self.reportPlayerAudioLang = function(videoNode as object, audioLang as string)
    self=m
    self.log(videoNode, "ConvivaClient reportPlayerAudioLang")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.audioLang = audioLang
      event.type = "ConvivaContentAudioLang"
      convivaTask.callFunc("dispatchEvent", event)
    end if
	end function

    ' Reports Subtitle Language change content session. This API must be used if Subtitle Language value is available from application.
	self.reportPlayerSubtitleLang = function(videoNode as object, subtitleLang as string)
    self=m
    self.log(videoNode, "ConvivaClient reportPlayerSubtitleLang")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.subtitleLang = subtitleLang
      event.type = "ConvivaContentSubtitleLang"
      convivaTask.callFunc("dispatchEvent", event)
    end if
	end function

      ' Reports CC Language change content session. This API must be used if CC Language value is available from application.
	self.reportPlayerCCLang = function(videoNode as object, ccLang as string)
    self=m
    self.log(videoNode, "ConvivaClient reportPlayerCCLang")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.ccLang = ccLang
      event.type = "ConvivaContentCCLang"
      convivaTask.callFunc("dispatchEvent", event)
    end if
	end function

  ' Monitors & integrates ad insights with Roku ads framework (CSAI only)
    self.monitorRaf = function(videoNode as object, rafInstance as object)
        self = m
        self.log(videoNode, "ConvivaClient monitorRaf")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid
			tempObj = {}
			tempObj.self = self
			tempObj.videoNode = videoNode
			tempObj.rafVersion = rafInstance.getLibVersion()
	    rafInstance.setTrackingCallback(self.rafAdTrackingCallback, tempObj)
	    rafInstance.setAdBufferRenderCallback(self.rafAdBufferCallback, tempObj)
		end if
	end function

  ' Monitors & integrates ad insights with Google DAI
  ' @params: videoNode that is responsible for ad playback
  ' streamManager instance created by Google DAI SDK.
	self.monitorGoogleDAI = function(videoNode as object, sdkInstance as object)
        self = m
        self.log(videoNode, "ConvivaClient monitorGoogleDAI")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid and sdkInstance <> invalid
        streamManager = sdkInstance.getStreamManager()
        self.convivaDaiVideoNode = videoNode
        streamManager.addEventListener(sdkInstance.AdEvent.ERROR, self.daiError)
        streamManager.addEventListener(sdkInstance.AdEvent.START, self.daiStart)
        streamManager.addEventListener(sdkInstance.AdEvent.FIRST_QUARTILE, self.daiFirstQuartile)
        streamManager.addEventListener(sdkInstance.AdEvent.MIDPOINT, self.daiMidpoint)
        streamManager.addEventListener(sdkInstance.AdEvent.THIRD_QUARTILE, self.daiThirdQuartile)
        streamManager.addEventListener(sdkInstance.AdEvent.COMPLETE, self.daiComplete)
        end if
	end function

  ' Monitors & integrates ad insights with YoSpace Ad Management SDK
  ' @params: videoNode that is responsible for ad playback
  ' yoSpaceSession: session instance created by YoSpace ad management SDK.
  self.monitorYoSpaceSDK = function(videoNode as object, yoSpaceSession as object)
    self = m
    self.log(videoNode, "ConvivaClient monitorYoSpaceSDK")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid and yoSpaceSession <> invalid
        self.convivaYoSpaceVideoNode = videoNode
        self.convivaYoSpaceSession = yoSpaceSession
        if yoSpaceSession.RegisterPlayer <> invalid
            player    = {}
            player["AdBreakStart"]    = yo_Callback(self.OnYoSpaceAdBreakStart, m)
            player["AdvertStart"]     = yo_Callback(self.OnYoSpaceAdStart, m)
            player["AdvertEnd"]       = yo_Callback(self.OnYoSpaceAdEnd, m)
            player["AdBreakEnd"]      = yo_Callback(self.OnYoSpaceAdBreakEnd, m)

            yoSpaceSession.RegisterPlayer(player)
        else if yoSpaceSession.AddAnalyticObserver <> invalid
            player    = {}
            player["OnAdvertBreakStart"]    = self.OnYoSpaceAdBreakStartV3
            player["OnAdvertStart"]     = self.OnYoSpaceAdStartV3
            player["OnAdvertEnd"]       = self.OnYoSpaceAdEnd
            player["OnAdvertBreakEnd"]      = self.OnYoSpaceAdBreakEnd
            yoSpaceSession.AddAnalyticObserver(YoAnalyticEventObserver(player, self))
        end if
    end if
end function

  ' Monitors & integrates ad insights with RAFX SSAI Adapters
  ' @params: videoNode that is responsible for ad playback
  ' adapter: instance returned from RAFX_SSAI() API. Works for all SSAI adapters supported by RAFX
	self.monitorRAFX = function(videoNode as object, adapter as object)
        self = m
        self.log(videoNode, "ConvivaClient monitorRAFX")
        convivaTask = self.getConvivaTask(videoNode)
        if convivaTask <> invalid and adapter <> invalid
        self.convivaRafxVideoNode = videoNode
        self.convivaRafxAdapter = adapter
        'adapter.addEventListener(adapter.AdEvent.PODS, self.rafxPodStart)
        adapter.addEventListener(adapter.AdEvent.POD_START, self.rafxPodStart)
        adapter.addEventListener(adapter.AdEvent.IMPRESSION, self.rafxAdEvent)
        adapter.addEventListener(adapter.AdEvent.FIRST_QUARTILE, self.rafxAdEvent)
        adapter.addEventListener(adapter.AdEvent.MIDPOINT, self.rafxAdEvent)
        adapter.addEventListener(adapter.AdEvent.THIRD_QUARTILE, self.rafxAdEvent)
        adapter.addEventListener(adapter.AdEvent.COMPLETE, self.rafxAdEvent)
        adapter.addEventListener(adapter.AdEvent.POD_END, self.rafxPodEnd)
        end if
	end function

	' Utility method used by RAF ad insights API: monitorRaf
	self.rafAdTrackingCallback = function(obj=Invalid as Dynamic, eventType = Invalid as Dynamic, ctx = Invalid as Dynamic)
	  	self = obj.self
	    adMetadata = {}
	    adMetadata.SetModeCaseSensitive()
	    if eventType = "PodStart" then
			if ctx.rendersequence = "preroll"
			    adMetadata["podPosition"] = "Pre-roll"
			else if ctx.rendersequence = "midroll"
			    adMetadata["podPosition"] = "Mid-roll"
			else if ctx.rendersequence = "postroll"
			    adMetadata["podPosition"] = "Post-roll"
			else
			    adMetadata["podPosition"] = "Unknown"
			end if
        self.reportAdBreakStarted(obj.videoNode, self.AD_TYPE.CLIENT_SIDE, adMetadata)
        else if eventType = "PodComplete" then
			if ctx.rendersequence = "preroll"
			    adMetadata["podPosition"] = "Pre-roll"
			else if ctx.rendersequence = "midroll"
			    adMetadata["podPosition"] = "Mid-roll"
			else if ctx.rendersequence = "postroll"
			    adMetadata["podPosition"] = "Post-roll"
			else
			    adMetadata["podPosition"] = "Unknown"
			end if
	        self.reportAdBreakEnded(obj.videoNode, self.AD_TYPE.CLIENT_SIDE, adMetadata)
	    else if eventType = "Start" then
	        adMetadata.assetName = "No ad title"
	        if ctx.ad.adtitle <> invalid and Len(ctx.ad.adtitle.trim()) <> 0
	          adMetadata.assetName = ctx.ad.adtitle
	        end if
	        adMetadata.contentLength = Int(ctx.ad.duration)

	        adMetadata.adid = ctx.ad.adid
	        adMetadata.adsystem = "NA"
	        adMetadata.mediaFileApiFramework = "NA"
	        adMetadata.sequence = stri(ctx.adindex).trim()
	        adMetadata.technology = self.AD_TYPE.CLIENT_SIDE
	        if ctx.rendersequence = "preroll"
	          adMetadata.position = "Pre-roll"
	        else if ctx.rendersequence = "midroll"
	          adMetadata.position = "Mid-roll"
	        else if ctx.rendersequence = "postroll"
	          adMetadata.position = "Post-roll"
	        end if
	        adMetadata.creativeId = ctx.ad.creativeid
	        adMetadata.adManagerName = "Roku ads framework"
	        adMetadata.adManagerVersion = obj.rafVersion
	        adMetadata.sessionStartEvent = "start"
          adMetadata.moduleName = "RC"
	        adMetadata.advertiser = ctx.ad.advertiser
	        adMetadata.streamUrl = ctx.ad.streams[0].url
            adMetadata.isLive = false
	        self.reportAdStart(obj.videoNode, adMetadata)
	    else if eventType = "Complete" then
	        self.reportAdEnded(obj.videoNode, adMetadata)
        else if eventType = "Pause" then
	        self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PAUSED)
        else if eventType = "Resume" then
	        self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PLAYING)
	    else if eventType = "Error" then
          errMsg = ctx.errMsg + " - " + ctx.errCode
          self.reportAdError(obj.videoNode, errMsg, 1)
	    end if

	  'end if
	end function

	' Utility function used by monitorRaf
	self.rafAdBufferCallback = function(obj=Invalid as Dynamic, eventType = Invalid as Dynamic, ctx = Invalid as Dynamic)
    self = obj.self
    ' Commenting as its causing lot of logs in HB, ignore warning during app launch time'
    ' if(ctx <> invalid)
    '   self.log(obj.videoNode, "rafAdBufferCallback")
    ' end if
    if eventType = "BufferingStart" or eventType="ReBufferingStart"
      self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.BUFFERING)
    else if eventType = "BufferingEnd" or eventType="ReBufferingEnd"
      self.reportAdPlayerState(obj.videoNode, self.PLAYER_STATE.PLAYING)
    end if
	end function

  'Internal to Google DAI module'
  self.daiStart = function (ad as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    ad.eventType = "Start"
    adInfo = self.constructDaiMetadata(ad)
    podInfo = {}
    podInfo.SetModeCaseSensitive()
    podInfo["podPosition"] = "NA"
    podInfo["podDuration"] = ad.adbreakinfo.duration
    self.reportAdBreakStarted(self.convivaDaiVideoNode, self.AD_TYPE.SERVER_SIDE, podInfo)
    self.reportAdStart(self.convivaDaiVideoNode, adInfo)
  end function
  'Internal to Google DAI module'
  self.daiFirstQuartile = function (ad as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    ad.eventType = "FirstQuartile"
    adInfo = self.constructDaiMetadata(ad)
    self.reportAdStart(self.convivaDaiVideoNode, adInfo)
  end function
  'Internal to Google DAI module'
  self.daiMidpoint = function (ad as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    ad.eventType = "MidPoint"
    adInfo = self.constructDaiMetadata(ad)
    self.reportAdStart(self.convivaDaiVideoNode, adInfo)
  end function
  'Internal to Google DAI module'
  self.daiThirdQuartile = function (ad as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    ad.eventType = "ThirdQuartile"
    adInfo = self.constructDaiMetadata(ad)
    self.reportAdStart(self.convivaDaiVideoNode, adInfo)
  end function

  'Internal to Google DAI module'
  self.daiComplete = function (ad as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    ad.eventType = "Complete"
    adInfo = self.constructDaiMetadata(ad)
    self.reportAdEnded(self.convivaDaiVideoNode, adInfo)
    podInfo = {}
    podInfo.SetModeCaseSensitive()
    podInfo["podPosition"] = "NA"
    podInfo["podDuration"] = ad.adbreakinfo.duration
    self.reportAdBreakEnded(self.convivaDaiVideoNode, self.AD_TYPE.SERVER_SIDE, podInfo)
  end function

  'Internal to Google DAI module'
  self.constructDaiMetadata = function (adData as object)
    adInfo = {}
    adInfo.SetModeCaseSensitive()
    if adData.adid <> invalid
      adInfo.adid = adData.adid
      adInfo.adsystem = adData.adsystem
      adInfo.adStitcher = "Google DAI"
      adInfo.sequence = stri(adData.adbreakinfo.adposition)
      adInfo.assetName = adData.adtitle
      adInfo.contentLength = Int(adData.duration)
    else
      adInfo.adid = "NA"
      adInfo.adsystem = "NA"
      adInfo.adStitcher = "NA"
      adInfo.sequence = "NA"
    end if
    adInfo.technology = "Server Side"
    adInfo.adManagerName = "Google IMA DAI SDK"
    adInfo.sessionStartEvent = ""+adData.eventType
    adInfo.advertiser = ""+adData.advertisername
    adInfo.moduleName = "GD"
    if adData.wrappers.count() > 0 or adData.wrappers = invalid
      adInfo.servingType = "Wrapper"
    else
      adInfo.servingType = "Inline"
    end if
    return adInfo
  end function

  self.daiError = function (adData as object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    errorMessage = "Error code:"+adData.id+" Error Message: "+adData.info
    self.reportAdError(self.convivaDaiVideoNode, errorMessage, self.ERROR_SEVERITY.FATAL)
  end function

  self.rafxPodStart = function (podInfo as Object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient

    m.rafxAdPod = podInfo["adPod"]
    m.rafxAdIndex = 0

    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    adMetadata.podDuration = podInfo["adPod"].duration
    if podInfo["adPod"].rendersequence = "preroll"
      adMetadata["podPosition"] = "Pre-roll"
    else if podInfo["adPod"].rendersequence = "midroll"
      adMetadata["podPosition"] = "Mid-roll"
    else
      adMetadata["podPosition"] = "Post-roll"
    end if
    self.reportAdBreakStarted(self.convivaRafxVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
  end function

  self.rafxPodEnd = function (podInfo as Object)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    adMetadata.podDuration = podInfo["adPod"].duration
    self.reportAdBreakEnded(self.convivaRafxVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
  end function

  self.rafxAdEvent = function (adInfo as object)
    adData = m.rafxAdPod.ads[m.rafxAdIndex]
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient

    if adInfo.event = "Start" or adInfo.event = "Impression"
      adInfo = {}
      adInfo.SetModeCaseSensitive()
      if adData <> invalid
        if adData.adtitle <> invalid
          adInfo.assetName = adData.adtitle
        else if adData.nativeAd <> invalid and adData.nativeAd.adTitle <> invalid
          adInfo.assetName = adData.nativeAd.adTitle
        end if
        if adData.adid <> invalid and adData.adid <> ""
          adInfo.adid = adData.adid
        else if adData.nativeAd <> invalid and adData.nativeAd.adId <> invalid and adData.nativeAd.adId <> ""
          adInfo.adid = adData.nativeAd.adId
        else
          adInfo.adid = "NA"
        end if
        if adData.adserver <> invalid and adData.adserver <> ""
          adInfo.adsystem = adData.adserver
        else if adData.nativeAd <> invalid and adData.nativeAd.adSystem <> invalid and adData.nativeAd.adSystem <> ""
          adInfo.adsystem = adData.nativeAd.adSystem
        else
          adInfo.adsystem = "NA"
        end if
      end if
      adInfo.technology = "Server Side"
      adInfo.adManagerName = "RAFX SSAI Adapter"
      adInfo.adManagerVersion = self.convivaRafxAdapter["__version__"]
      adInfo.sessionStartEvent = "Impression"
      ' https://developer.roku.com/en-gb/docs/developer-program/advertising/ssai-adapters.md#1-loading-the-adapter
      ' CE-7220 : Can extract the stitcher used from the name
      stitcher = self.convivaRafxAdapter["__name__"]
      if stitcher <> invalid and stitcher <> ""
        adInfo.adStitcher = stitcher
      else
        adInfo.adStitcher = "NA"
      end if
      adInfo.isSlate = "false"
      adInfo.mediaFileApiFramework = "NA"
      if m.rafxAdPod.rendersequence = "preroll"
        adInfo.position = "Pre-roll"
      else if m.rafxAdPod.rendersequence = "midroll"
        adInfo.position = "Mid-roll"
      else if m.rafxAdPod.rendersequence = "postroll"
        adInfo.position = "Post-roll"
      end if
      if adData <> invalid and adData.streams.count() > 0
        adInfo.streamUrl = adData.streams[0].url
      end if
      if adData <> invalid and adData.duration > 0
        adInfo.contentLength = Int(adData.duration)
      end if
      adInfo.defaultReportingResource = ""
      adInfo.streamFormat = "hls"
      adInfo.moduleName = "RS"
      self.reportAdStart(self.convivaRafxVideoNode, adInfo)
    else if adInfo.event = "Complete" then
      self.reportAdEnded(self.convivaRafxVideoNode, adInfo)
      m.rafxAdIndex += 1
    end if
  end function

  self.OnYoSpaceAdBreakStart = function (breakInfo = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient

    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    if breakInfo <> invalid
      ad_position = self.convivaYoSpaceSession.GetCurrentAdBreak().getPosition()
      if ad_position = "preroll"
        adMetadata["podPosition"] = "Pre-roll"
      else if ad_position = "midroll"
        adMetadata["podPosition"] = "Mid-roll"
      else if ad_position = "postroll"
        adMetadata["podPosition"] = "Post-roll"
      else
        adMetadata["podPosition"] = ad_position
      end if

      adMetadata["podDuration"] = Int(breakInfo.GetDuration())
    end if

    self.reportAdBreakStarted(self.convivaYoSpaceVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
  end function

  self.OnYoSpaceAdBreakStartV3 = function (breakInfo = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient

    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    'breakInfo.GetPosition() api introduced in v3 but api returns unknown always
    ' and if we use old way to determine pod position there we cannot determine postroll ads
    ' so we are using old api to get pod position untill new api is resolved
    if breakInfo <> invalid
        ad_position = breakInfo.getPosition()
        if ad_position = "preroll"
          adMetadata["podPosition"] = "Pre-roll"
        else if ad_position = "midroll"
          adMetadata["podPosition"] = "Mid-roll"
        else if ad_position = "postroll"
          adMetadata["podPosition"] = "Post-roll"
        else
          adMetadata["podPosition"] = ad_position
        end if
        adMetadata["podDuration"] = Int(breakInfo.GetDuration())
    end if

    self.reportAdBreakStarted(self.convivaYoSpaceVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
  end function

  self.OnYoSpaceAdBreakEnd = function (breakInfo = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    adMetadata = {}
    adMetadata.SetModeCaseSensitive()
    self.reportAdBreakEnded(self.convivaYoSpaceVideoNode, self.AD_TYPE.SERVER_SIDE, adMetadata)
  end function

  self.OnYoSpaceAdStart = function (adData = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    adInfo = {}
    adInfo.SetModeCaseSensitive()
    if self.convivaYoSpaceSession.GetSessionProperties() <> invalid
      advert = self.convivaYoSpaceSession.GetCurrentAdvert()
      if (advert <> invalid)
          ' if (advert.GetAdvert() <> invalid)
          adInfo.adid = advert.GetAdvertID()
          adSystem = advert.GetProperty("AdSystem")
          if(adSystem <> invalid) then
              adInfo.adsystem = adSystem.GetValue()
          else
              adInfo.adsystem = "NA"
          end if
          adInfo.assetName = advert.GetProperty("AdTitle").getValue()
          ' adInfo.advertiser = advert.GetAdvert().GetAdvertiser()
          if advert.GetProperty("Advertiser") <> invalid
            adInfo.advertiser = advert.GetProperty("Advertiser").getValue()
          end if
          ' CSR-4960 fix for sequence
          if advert.GetSequence() <> invalid
            adInfo.sequence = advert.GetSequence().ToStr()
          end if
          ' FR-2315
          lineage = advert.GetLineage()
          if (lineage <> invalid) then
            if( lineage.GetAdId() <> invalid) then
                adInfo.firstAdId = lineage.GetAdId()
            else
                adInfo.firstAdId = "NA"
            end if
            if( lineage.GetAdSystem() <> invalid) then
                adInfo.firstAdSystem = lineage.GetAdSystem()
            else
                adInfo.firstAdSystem = "NA"
            end if
            if( lineage.GetCreativeId() <> invalid) then
                adInfo.firstCreativeId = lineage.GetCreativeId()
            else
                adInfo.firstCreativeId = "NA"
            end if
          end if
          ' end if
          if advert.isFiller() = true
              adInfo.isSlate = "true"
          else
              adInfo.isSlate = "false"
          end if

          ad_position = self.convivaYoSpaceSession.GetCurrentAdBreak().getPosition()
          if ad_position = "preroll"
            adInfo.position = "Pre-roll"
          else if ad_position = "midroll"
            adInfo.position = "Mid-roll"
          else if ad_position = "postroll"
            adInfo.position = "Post-roll"
          else
            adInfo.position = ad_position
          end if

          if (advert.getLinearCreative().GetCreativeIdentifier() <> invalid)
            adInfo.creativeId = advert.getLinearCreative().GetCreativeIdentifier()
          else
            adInfo.creativeId = "NA"
          end if
          adInfo.contentLength = Int(advert.GetDuration())

      end if
      if self.convivaYoSpaceSession.GetSessionProperties()._CLASSNAME <> "YSLiveSession"
          adInfo.isLive = false
      else
          adInfo.isLive = true
      end if
    end if
    ' adInfo.streamUrl = self.convivaYoSpaceSession.GetMasterPlaylist()
    adInfo.streamUrl = self.convivaYoSpaceSession.GetPlaybackUrl()
    adInfo.mediaFileApiFramework = "NA"
    adInfo.technology = "Server Side"
    ' adInfo.streamFormat = self.convivaYoSpaceSession.GetSessionProperties().GetStreamType() 'if you uncomment this line you will get crash.
    adInfo.adManagerName = "YoSpace SDK"
    ' adInfo.adManagerVersion = self.convivaYoSpaceSession.GetVersion()
    adInfo.adManagerVersion = self.convivaYoSpaceSession.__version
    adInfo.adstitcher = "YoSpace CSM"
    adInfo.moduleName = "YS"
    self.reportAdStart(self.convivaYoSpaceVideoNode, adInfo)
  end function

  self.OnYoSpaceAdStartV3 = function (adData = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    adInfo = {}
    adInfo.SetModeCaseSensitive()
    if self.convivaYoSpaceSession <> invalid
      advert = self.convivaYoSpaceSession.GetCurrentAdvert()
      if (advert <> invalid)
          if (advert.GetProperty <> invalid)
              adInfo.adid = advert.GetIdentifier()
              adSystem = advert.GetProperty("AdSystem")
                if(adSystem <> invalid) then
                    adInfo.adsystem = adSystem.GetValue()
                else
                    adInfo.adsystem = "NA"
                end if
              adTitle = advert.GetProperty("AdTitle")
                if(adTitle <> invalid) then
                    adInfo.assetName = adTitle.GetValue()
                else
                    adInfo.assetName = invalid
                end if
              advertiser = advert.GetProperty("Advertiser")
                if(advertiser <> invalid) then
                    adInfo.advertiser = advertiser.GetValue()
                else
                    adInfo.advertiser = invalid
                end if
              ' CSR-4960 fix for sequence
              if advert.GetSequence() <> invalid
                adInfo.sequence = Str(advert.GetSequence())
              end if
              ' FR-2315
              lineage = advert.GetLineage()
              if (lineage <> invalid) then
                if( lineage.GetIdentifier() <> invalid) then
                    adInfo.firstAdId = lineage.GetIdentifier()
                else
                    adInfo.firstAdId = "NA"
                end if
                if( lineage.GetAdSystem() <> invalid) then
                    adInfo.firstAdSystem = lineage.GetAdSystem()
                else
                    adInfo.firstAdSystem = "NA"
                end if
                if( lineage.GetCreativeIdentifier() <> invalid) then
                    adInfo.firstCreativeId = lineage.GetCreativeIdentifier()
                else
                    adInfo.firstCreativeId = "NA"
                end if
              end if
          end if
          if advert.IsFiller() = true
              adInfo.isSlate = "true"
          else
              adInfo.isSlate = "false"
          end if
          ' breakInfo.GetPosition() api introduced in v3 but api returns unknown always
          ' and if we use old way to determine pod position there we cannot determine postroll ads
          ' so we are using old api to get pod position untill new api is resolved
          ad_position = self.convivaYoSpaceSession.GetCurrentAdBreak().getPosition()
          if ad_position = "preroll"
            adInfo.position = "Pre-roll"
          else if ad_position = "midroll"
            adInfo.position = "Mid-roll"
          else if ad_position = "postroll"
            adInfo.position = "Post-roll"
          else
            adInfo.position = ad_position
          end if
          if(advert.GetLinearCreative() <> invalid) then
            adInfo.creativeId = advert.GetLinearCreative().GetCreativeIdentifier()
          else
            adInfo.creativeId = "NA"
          end if
            adInfo.contentLength = Int(advert.GetDuration())
      end if
      adInfo.isLive = false
      if Instr(1, self.convivaYoSpaceSession._CLASSNAME, "Live") > 0
        adInfo.isLive = true
      end if
    end if
    adInfo.streamUrl = self.convivaYoSpaceSession.GetStreamUrl().ToString()
    adInfo.mediaFileApiFramework = "NA"
    adInfo.technology = "Server Side"
    ' adInfo.streamFormat = self.convivaYoSpaceSession.GetStreamType()
    adInfo.adManagerName = "YoSpace SDK"
    if self.convivaYoSpaceSession.__version <> invalid
      adInfo.adManagerVersion = self.convivaYoSpaceSession.__version
    end if

    adInfo.adstitcher = "YoSpace CSM"
    adInfo.moduleName = "YS"
    self.reportAdStart(self.convivaYoSpaceVideoNode, adInfo)
  end function

  self.OnYoSpaceAdEnd = function(adData = invalid as Dynamic)
    globalAA = getGlobalAA()
    self = globalAA.ConvivaClient
    adInfo = {}
    self.reportAdEnded(self.convivaYoSpaceVideoNode, adInfo)
  end function

  self.setCDNServerIP = function (videoNode as object, cdnServerIPAddress as string)
    self=m
    self.log(videoNode, "ConvivaClient setCDNServerIP")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.cdnServerIPAddress = cdnServerIPAddress
      event.type = "ConvivaCDNServerIP"
      convivaTask.callFunc("dispatchEvent", event)
    end if
  end function

  self.log = function (videoNode as object, msg as string)
    self = m
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.msg = msg
      event.type = "ConvivaLog"
      convivaTask.callFunc("dispatchEvent", event)
    end if
  end function

  self.setUserPreferenceForDataCollection = function(videoNode as object, prefs as object)
    self=m
    self.log(videoNode, "ConvivaClient setUserPreferenceForDataCollection")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.prefs = prefs
      event.type = "ConvivaUserPreferenceForDataCollection"
      convivaTask.callFunc("dispatchEvent", event)
    end if
  end function

  self.setUserPreferenceForDataDeletion = function(videoNode as object, prefs as object)
    self=m
    self.log(videoNode, "ConvivaClient setUserPreferenceForDataDeletion")
    convivaTask = self.getConvivaTask(videoNode)
    if convivaTask <> invalid
      event = {}
      event.prefs = prefs
      event.type = "ConvivaUserPreferenceForDataDeletion"
      convivaTask.callFunc("dispatchEvent", event)
    end if
  end function


  return self
end function
