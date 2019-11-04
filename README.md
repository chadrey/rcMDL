# NetLinx Module Implementation
This is a description of a netlinx module template that is SNAPI-ish.  It implements rcMDL.axi (i.e. ip communication, que, poll, and misc helpers).

The template is designed for either 232 or IP using dvDEV.NUMBER.

If your device does not support both, it is suggested you leave the plumbing in-place anyway.

# Module Documentation
These items should be documented at the top of the netlinx module's axs file.

## Helpful Links
* [Link to API](https://google.com)
* [Link to Owners Manual](https://google.com)

## 232 Control
* Cable: not identified
* Baud rate: 9600,N,8,1

## IP Control
* Default IP: 192.168.0.2
* IP Port: 23
* User Name:
* Password:

# Properties

## Static properties (read-only)
```
?DEV_INFO
* Returns:
  DEV_INFO-MAKE,<value>
  DEV_INFO-MODEL,<value>
  DEV_INFO-ASSETTYPE,<value>
```

## Dynamic properties
```
?PROPERTIES
* Returns all properties supported.

* Time delay properties (setters and getters)
  PROPERTY-POLL_TIME,<value>
  PROPERTY-RECONNECT_TIME,<value>

* IP comm properties (setters and getters)
  PROPERTY-IP_ADDRESS,<value>
  PROPERTY-PORT,<value>
  PROPERTY-USER_NAME,<value>
  PROPERTY-PASSWORD,<value>

* Has Components (getters only):
  ?PROPERTY-HAS-POWER
  ?PROPERTY-HAS-INPUT-SELECT
  ?PROPERTY-HAS-VOLUME,<count>
  ?PROPERTY-HAS-ROUTER,<count>
```

# SNAPI Compliance

## Heartbeat
A heartbeat is enabled, but will not close the IP socket after 3 failed attempts.  Instead, DATA_INITIALIZED and DEVICE_COMMUNICATING are reset.

## Polling
There is a polling routine that fires every POLL_TIME (usually 5 seconds), counts from 1 to n (i.e. ?PWR,?INPSEL,?VOL,etc), and then repeats continuously.

If the device supports the PWR component, then the polling routine will poll for power until the device has replied as ON.  Then the polling cycle will continue from 2 to n.

## DEVICE_COMMUNICATING
Any reply that is properly terminated with the correct delimiter (i.e. cr, cr/lf, etc) is considered true for DEVICE_COMMUNICATING.

A poll counter is used to determine when 5 or more poll events did not receive a proper reply and DEVICE_COMMUNICATING is set to false.

## DATA_INITIALIZED
Once the polling routine has completed a full polling cycle and DEVICE_COMMUNICATING is true, then DATA_INITIALIZED is turned on.  It essentially represents that all state for a device has been requested and assumed to have been properly received.

## SNAPI Limitations
The module does it's best to be SNAPI compliant.  There are however situations where this module will diverge.  Those are noted below and are a **MUST READ**.

* Level controls and feedback are raw values only (not 0-255) [#1].
* Channels that ramp levels are not supported (i.e. VOL_UP/VOL_DOWN) [#2].
* Discrete channel control is not supported [#3].
* Channel controls trigger with the ON event only [#4].
* Commands are extended and provide more capabilities [#5].

**Notes**
* **#1** Levels that scale (i.e. 0-255 converting to 0-100) can produce jitter based upon some INT math problems. When the device is not connected, you probably won't see a problem, but when the device starts providing responses, jitter occurs and you can end up in a race condition.
* **#2** Instead of ramping channels, you can simply use a PUSH-HOLD[x,repeat]-RELEASE instead.
* **#3** This is a bit tricky to pull off, so it's best to not support it.
* **#4** From the outside, you'll want to stick with PULSE.
* **#5** Commands and parameters you wish SNAPI supported but doesn't.

# Components
## Module
```
REINIT
* Used to reinitialize the module, usually following a property assignment.
```

```
PASSTHRU-<data>[,<alias>,<lDelay (in mS)>]
* Used to send raw data to the connected device.
* The data delimiter is optional and would be added for you (i.e. cr or cr/lf).
* Alias is optional and good for DEBUG_TX/DEBUG_RX.
* lDelay is optional and good for testing.
```

```
* Misc channel support:
  * DEVICE_COMMUNICATING
  * DATA_INITIALIZED
  * QUE_EDGE (500)
  * DEBUG_TX (501)
  * DEBUG_RX (502)
```

## Communication

Any IP communication is designed to keep the connection alive if necessary (i.e. polling or queued items to send).  If there is nothing else to send, the IP socket will close.  If a command needs to be sent, the socket will open (if closed) and que up the item to send with the online event.

```
?COMM
* Used to quickly check communication status.
* Returns:
  COMM-<D:P:S of real device>
    ONLINE:<TRUE or FALSE>
    CONNECTION_STATE: <Blank,CONNECTING,WAITING>
    DATA_INITIALIZED:<TRUE or FALSE>
    DEVICE_COMMUNICATING:<TRUE or FALSE>
    PROPERTY-POLL_TIME,<value>
    PROPERTY-IP_ADDRESS,<value>
    PROPERTY-PORT,<value>
    PROPERTY-RECONNECT_TIME,<value>
```

```
IP_OPEN-<IP Address>[,<Port>,<User>,<Password>]
* Quick utility, good for testing.
* Simply a macro for IP assignment with a REINIT.
```

```
IP_CLOSE
* Quick utility, good for testing.
```

## Power
```
With support for these SNAPI channels:
  * POWER
  * PWR_ON
  * PWR_OFF
  * POWER_FB
  * WARMING_FB (227)
  * COOLING_FB (228)

With additional support for these commands:

?PWR
* Returns:
  * PWR-<ON,OFF,UNKNOWN>

PWR-<ON,OFF,TGL>
* Turn the device on or off.
* Returns:
  * PWR-<ON,OFF>,<delay>
  * Where delay is countdown value (in Seconds)

PWR-MACRO,<srcSelAlias>
* Quick utility, checks for PWR_ON with a source selection.

WARMUP-<value>
COOLDOWN-<value>
* Both getters and setters to adjust the delay time (as Seconds).
* During on/off transition, you'll receive a countdown:
  * WARMING-<current>,<total>
  * COOLING-<current>,<total>
```

## Input Selection
```
This module contains these source indexes and aliases:
* 1, HDMI1
* 2, HDMI2

With support for these custom SNAPI channels:
  * INPSEL01 - INPSEL10 (31-40)

INPUTSELECT-<index>
* Use this with an indexed selection.

INPUTSELECT_ALIAS-<alias>
* Quick utility, use this with an aliased selection.

?INPUTSELECT
* Returns the current selection:
  * INPUTSELECT-<index>,<alias>

?INPUTCOUNT
* Returns the number of sources available.
  * INPUTCOUNT-<count>

?INPUTPROPERTIES
* Returns the list of sources (see INPUTPROPERTY)

?INPUTPROPERTY-<index>
* Returns the arguments for this source index.
  * INPUTPROPERTY-<index>,<inputGroup>,<signalType>,<deviceLabel>,<displayName>
    * index: 1 to INPUTCOUNT
    * inputGroup: always 0
    * signalType: TSE values (i.e. HDMI,VGA,RGB,DP,USB)
    * deviceLabel: The alias
    * displayName: friendly helper (i.e. Side,Front, Back)
```

# Containers
Containers are components that support a 1 to many (count).  The first argument is usually the index (from 1 to Count).

## Volume
```
This module assigns these default values:
* Vol Count: 10
* Vol Min: -60
* Vol Max:  20

With support for these SNAPI channels (for index 1 only):
  * VOL_MUTE
  * VOL_MUTE_ON
  * VOL_MUTE_FB

With support for these SNAPI levels (for index 1 only):
  * VOL_LVL

With additional support for these commands:

?VOL_LVL_COUNT  **READ ONLY**
* Returns the maximum number to support:
  * VOL_LVL_COUNT-<value>

?VOL_MUTE-<index>
* Returns:
  * VOL_MUTE-<index>,<ON,OFF,UNKNOWN>

VOL_MUTE-<index>,<ON,OFF,TGL>
* Set the volume mute on or off.

?VOL_LVL-<index>
* Returns the current volume:
  * VOL_LVL-<index>,<snValue>,<nValueBG>

VOL_LVL-<index>,<snValue>
* Absolute volume assignment.

VOL_STEP-<index>,<snValue>
* Relative volume assignment.

?VOL_LVL_RANGE-<index>
* Returns the snMin and snMax:
  * VOL_LVL_RANGE-<index>,<snMin>,<snMax>

VOL_LVL_RANGE-<index>,<snMin>,<snMax>
* Assigns the snMin and snMax values.
```

## Router
```
This module assigns these as default values:
* Router Count: 1
* Maximum Input Count: 40
* Maximum Output Count: 40

?RTR_COUNT  **READ ONLY**
* Returns the maximum number to support:
  * RTR_COUNT-<value>

?ROUTER_SIZE-<index>
* Returns the input/output count:
  * ROUTER_SIZE-<index>,<InputCnt>,<OutputCnt>

ROUTER_SIZE-<index>,<InputCnt>,<OutputCnt>
* Assigns the input/output count:
* The counts cannot exceed the module maximums.

ROUTE_VIDEO-<index>,<input>,<output>
ROUTE_AUDIO-<index>,<input>,<output>
ROUTE-<index>,<input>,<output>
* Routes the input to the output for the signal type.

ROUTE_VIDEO_MANY-<index>,<input>,"<outputList>"
ROUTE_AUDIO_MANY-<index>,<input>,"<outputList>"
ROUTE_MANY-<index>,<input>,"<outputList>"
* Routes the input to the many outputs for the signal type.
```

## Dialer
```
TBD...
```

## Source Selector
```
TBD...
```


## Crosspoint Matrix
```
TBD...
```
