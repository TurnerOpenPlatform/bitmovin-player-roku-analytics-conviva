# Bitmovin Player Conviva Analytics Integration

## Limitations
Currently we don't support ad tracking at all.

## Compatibility
**This version of the Conviva Analytics Integration works only with Player Version >= 1.4.x.
The recommended version of the Conviva SDK is 2.151.0.36978.**

## Getting Started
1. Clone Git repository

## Usage

### Use as Component Library

1. Fetch conviva SDK
  - Download conviva sdk source file
  - Rename to `Conviva_Roku.brs`
  - But it into `./ConvivaIntegration/source`
2. run `npm install & npm run build`
3. Include the created ZIP from the `./dist` folder into your channel as component library
  ```Brightscript
  m.conviva = CreateObject("roSGNode", "ComponentLibrary")
  m.conviva.id = "conviva"
  m.conviva.uri = "http://PATH_TO_YOUR_ZIP.zip"
  m.top.appendChild(m.conviva)
  m.conviva.observeField("loadStatus", "YOUR_CALLBACK") ' Ensure the library is loaded
  ```

### Use with Source Code

1. Fetch conviva SDK
  - Download conviva sdk source file
  - Rename to `Conviva_Roku.brs`
  - Create a folder in your root folder called `conviva`
  - But the `Conviva_Roku.brs` into the new created `./conviva` folder. _If you want to create a different folder structure you need to change the import of the `ConvivaSDK` within the `ConvivaAnalyticsTask.xml`_
2. Copy following files to your project:
  - `./ConvivaIntegration/components/ConvivaAnalytics.brs`
  - `./ConvivaIntegration/components/ConvivaAnalytics.xml`
  - `./ConvivaIntegration/components/ConvivaAnalyticsTask.brs`
  - `./ConvivaIntegration/components/ConvivaAnalyticsTask.xml`

### Create an instance

1. Create a instance of `ConvivaAnalytics`

  _Ensure that the bitmovinPlayer exists here as well_
  ```Brightscript
  m.convivaAnalytics = CreateObject("roSGNode", "conviva:ConvivaAnalytics") 'A ConvivaAnalytics instance is always tied to one player instance
  customerKey = "YOUR_CUSTOMER_KEX"
  config = {
    debuggingEnabled : true
    gatewayUrl : "YOUR_GATEWAY_URL" ' optional and only for testing
  }
  m.convivaAnalytics.callFunc("setup", m.bitmovinPlayer, customerKey, config)

  ' Initialize ConvivaAnalytics before calling setup or load on the bitmovinPlayer
  m.bitmovinPlayer.callFunc(m.BitmovinFunctions.SETUP, m.playerConfig)
  ```

### Advanced Usage

#### Custom Deficiency Reporting (VPF)

If you would like to track custom VPF (Video Playback Failures) events when no actual player error happens (e.g.
endless stalling due to network condition) you can use following API to track those deficiencies.

```Brightscript
m.convivaAnalytics.callFunc("reportPlaybackDeficiency", "MY_ERROR_MESSAGE", true, true)
```

_See [ConvivaAnalytics.brs](./ConvivaIntegration/components/ConvivaAnalytics.brs) for more details about the parameters._

#### Custom Events

If you want to track custom events you can do so by adding the following:

For an event not bound to a session, use:
```Brightscript
m.convivaAnalytics.callFunc("sendCustomApplicationEvent", "MY_EVENT_NAME", {
  eventAttributeKey: "eventAttributeValue"
})
```

For an event bound to a session, use:
```Brightscript
m.convivaAnalytics.callFunc("sendCustomPlaybackEvent", "MY_EVENT_NAME", {
  eventAttributeKey: "eventAttributeValue"
})
```

_See [ConvivaAnalytics.brs](./ConvivaIntegration/components/ConvivaAnalytics.brs) for more details._

#### Content Metadata Handling

If you want to override some content metadata attributes you can do so by adding the following:

```Brightscript
contentMetadataOverrides = {
  playerName: "Conviva Integration Test Channel",
  viewerId: "MyAwesomeViewerId",
  tags: {
    CustomKey: "CustomValue"
  }
}
m.convivaAnalytics.callFunc("updateContentMetadata", contentMetadataOverrides)
```

#### End a Session

If you want to end a session manually you can do so by adding the following:

```Brightscript
m.convivaAnalytics.callFunc("endSession")
```
