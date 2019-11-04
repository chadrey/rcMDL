MODULE_NAME='MDL_TEMPLATE' (DEV vdvMAIN, DEV dvDEV)
/*-----------------------------------------------------------
  -----------------------------------
   Copyright 2019 Chad Reynoldson
  -----------------------------------
    This file is part of rcMDL.

    rcMDL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    rcMDL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with rcMDL.  If not, see <http://www.gnu.org/licenses/>.


   About:
  -----------------------------------
   Name      - MDL_TEMPLATE
   Equipment - Module device driver for <make> <model> as <assetType>.


   Control Types:
  -----------------------------------
   232      - 9600,N,8,1 (cable: not identified)
   Ethernet - TCP at port 23 (IP Default: 192.168.0.2)


   Programmer:
  -----------------------------------
   Company  - Reynoldson Control Inc.
   Phone    - (402) 489-1220
   Website  - www.ReynoldsonControl.com
   Contact  - Chad Reynoldson


   Revisions:
  -----------------------------------
   Revision - 0.0.0  11/01/2019  CWR
   - Initial creation.


   Comments:
  -----------------------------------
   - This module should come with a markdown file detailing the interface.
   - This module is designed for either 232 or IP using dvDEV.NUMBER.
     - If your device does not support both, I suggest you leave
       the plumbing in-place anyway.
   - Mandatory timelines: TL_QUE
     - The driver is based upon commands flowing thru the que.
   - Optional timelines:  TL_POLL, TL_IP_RECONNECT, TL_COUNTER_PWR
     - The driver and rcMDL are designed to compile w/o them.
   - SNAPi support has it's limits:
     - All levels, both in and out, are raw values (not 0-255).
     - Channels that ramp are not supported (i.e. VOL_UP,VOL_DN).
     - Any channel listeners execute with the ON event only (i.e. you can only PULSE).
     - Discrete channel controls are not supported (i.e. POWER_ON).
   - Notes on device translation:
     - When you activate a chn on vdvAPI, the event/state hits outside (not inside).
     - When you check a chn's ON state, you need to use vdvMAIN.
     - When you activate a lvl on vdvAPI, the event hits outside (not inside).


   Links:
  -----------------------------------
   -[Link to API](https://google.com#q=<make> <model> api)
   -[Link to Owners Manual](https://google.com#q=<make> <model> owners manual)
-------------------------------------------------------------*/

//==============================================================================
// SNAPI Emulation
//==============================================================================
INCLUDE 'SNAPI'


//==============================================================================
// Devices
//==============================================================================
DEFINE_DEVICE

vdvAPI = DYNAMIC_VIRTUAL_DEVICE


//==============================================================================
// Constants
//==============================================================================
DEFINE_CONSTANT

//-- Virtual API channels (SNAPI addons) -------------------
//-- Config --------
VCHN_CNT            = 500
VLVL_CNT            = 8

//-- Chn: Misc -----
WARMING_FB          = 227
COOLING_FB          = 228

//-- Chn: Comm -----
QUE_EDGE            = 500
DEBUG_TX            = 501
DEBUG_RX            = 502

//-- Chn: InpSel ---
INPSEL01            = 31            // HDMI1
INPSEL02            = 32            // HDMI2
INPSEL03            = 33
INPSEL04            = 34
INPSEL05            = 35
INPSEL06            = 36
INPSEL07            = 37
INPSEL08            = 38
INPSEL09            = 39
INPSEL10            = 40


//-- Extended Component Settings ---------------------------
//-- Volume --------
VOL_CNT             = 10
SINTEGER VOL_MIN    = -60
SINTEGER VOL_MAX    = 20

//-- Router --------
RTR_CNT             = 1
RTR_INP_MAX         = 40
RTR_OUT_MAX         = 40


//-- Timelines ---------------------------------------------
TL_QUE              = 1
TL_HEARTBEAT        = 2
TL_POLL             = 3
TL_IP_RECONNECT     = 4
TL_COUNTER_PWR      = 5


//==============================================================================
// Types
//==============================================================================
DEFINE_TYPE

//-- Components --------------------------------------------
//-- Level -------------------------
STRUCTURE _uLvl
{
	CHAR     cAlias[30]
  SINTEGER snMin
  SINTEGER snMax
  SINTEGER snValue
  INTEGER  nBG
  CHAR     bMuted
}


//-- Containers --------------------------------------------
//-- Volume Levels -----------------
STRUCTURE _uVol
{
  _uLvl    uLvl
}

//-- Router ------------------------
STRUCTURE _uRtr
{
  INTEGER  nOut[RTR_OUT_MAX]
  INTEGER  nVidOut[RTR_OUT_MAX]
  INTEGER  nAudOut[RTR_OUT_MAX]
  INTEGER  nInpCnt
  INTEGER  nOutCnt
}


//-- Devices -----------------------------------------------
//-- State -------------------------
STRUCTURE _uState
{
  CHAR    bPwr
  CHAR    cInpSel[10]
  INTEGER nInpSel
}


//-- Device Properties -------------
STRUCTURE _uProp
{
  CHAR    cMake[128]
  CHAR    cModel[128]
  CHAR    cAssetType[30]

  URL_STRUCT uIP

  INTEGER nPonDelay
  INTEGER nPofDelay
  INTEGER nPollDelay
  INTEGER nIpOpenDelay
}

//-- Device Communication ----------
STRUCTURE _uComm
{
  CHAR    cConnectionState[15]
  CHAR    bConnected

  CHAR    bEchoTX
  CHAR    bEchoRX

  INTEGER nHeartbeatCounter

  INTEGER nPollStep
  INTEGER nPollCounter
}

//-- Device Que --------------------
STRUCTURE _uQueItem
{
	CHAR    cAlias[30]
	CHAR    cData[50]
	LONG    lDelay
}

STRUCTURE _uQue
{
	_uQueItem uItem[100]
	_uQueItem uLastItem

	INTEGER nCurrent
	INTEGER nLast
}

//-- Device Buffer -----------------
STRUCTURE _uBuff
{
  CHAR    cReply[50]
  CHAR    cBuff[500]
}

//-- Counters ----------------------------------------------
STRUCTURE _uCounter
{
  INTEGER nCount
  INTEGER nStart
  CHAR    cContext[30]
}


//==============================================================================
// Variables
//==============================================================================
DEFINE_VARIABLE

//-- Driver ------------------------------------------------
VOLATILE _uState uState

VOLATILE _uProp  uProp
VOLATILE _uComm  uComm
VOLATILE _uQue   uQue
VOLATILE _uBuff  uBuff


//-- Containers --------------------------------------------
VOLATILE _uVol   uVol[VOL_CNT]
VOLATILE _uRtr   uRtr[RTR_CNT]


//-- Counters ----------------------------------------------
VOLATILE _uCounter uCounterPwr


//-- For rcMDL ---------------------------------------------
VOLATILE CHAR    cDevNum[18]
VOLATILE CHAR    bAPI_IS_HEX = FALSE
VOLATILE CHAR    cMDL_NAME[] = 'MDL_TEMPLATE'


//==============================================================================
// Helpers
//==============================================================================
INCLUDE 'rcMDL'


//==============================================================================
// Functions
//==============================================================================

//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Module helpers -----------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Send to device.
//----------------------------------------------------------
DEFINE_FUNCTION sendTo (CHAR cAlias[], CHAR cData[], LONG lDelay)
{
  IF((dvDEV.NUMBER = 0) && !uComm.bConnected) {
    IF(LENGTH_STRING(uProp.uIP.URL))
      ipOpen ()
  }

  queAdd (cAlias, cData, lDelay)
}

//----------------------------------------------------------
// Send a heartbeat.
//----------------------------------------------------------
DEFINE_FUNCTION sendHeartbeat ()
{
  sendTo ('HEARTBEAT', "13", 200)
}

//----------------------------------------------------------
// Initialize module for the first time.
//----------------------------------------------------------
DEFINE_FUNCTION moduleInit ()
STACK_VAR
  INTEGER nLoop
{
//-- Containers --------------------
//-- Volume --------
  FOR(nLoop=1; nLoop<=VOL_CNT; nLoop++) {
    uVol[nLoop].uLvl.snMin = VOL_MIN
    uVol[nLoop].uLvl.snMax = VOL_MAX
  }

//-- Router --------
  FOR(nLoop=1; nLoop<=RTR_CNT; nLoop++) {
    uRtr[nLoop].nInpCnt = RTR_INP_MAX
    uRtr[nLoop].nOutCnt = RTR_OUT_MAX
  }

//-- Reinit ------------------------
  moduleReinit ()
}

//----------------------------------------------------------
// Re-Initialize state, comm, que, and poll.
//----------------------------------------------------------
DEFINE_FUNCTION moduleReinit ()
STACK_VAR
  INTEGER nLoop
  INTEGER nLoop2
{
//-- Device ------------------------
  uState.bPwr    = FALSE
  uState.nInpSel = 0

//-- Containers --------------------
//-- Volume --------
  FOR(nLoop=1; nLoop<=VOL_CNT; nLoop++) {
    uVol[nLoop].uLvl.snValue = uVol[nLoop].uLvl.snMin
    uVol[nLoop].uLvl.nBG     = 0
    uVol[nLoop].uLvl.bMuted  = 255
  }

//-- Router --------
  FOR(nLoop=1; nLoop<=RTR_CNT; nLoop++) {
    FOR(nLoop2=1; nLoop2<=uRtr[nLoop].nOutCnt; nLoop2++) {
      uRtr[nLoop].nOut[nLoop2] = 255
    }
  }

//-- Reset FB ----------------------
  moduleFB ()

//-- SNAPI -------------------------
  OFF[vdvAPI,DEVICE_COMMUNICATING]
  OFF[vdvAPI,DATA_INITIALIZED]

//-- Que ---------------------------
  queReset ()

//-- Heartbeat ---------------------
  heartbeatStop ()

//-- Poll --------------------------
  pollStop ()

//-- IP Restart --------------------
  IF(dvDEV.NUMBER = 0) {
    ipClose ()

    CANCEL_WAIT 'REINIT'
    WAIT 50 'REINIT'
      ipOpen ()
  }

//-- 232 Restart -------------------
  IF(DEVICE_ID(dvDEV) && (dvDEV.NUMBER > 0)) {
    IF(uProp.nPollDelay) {
      pollStart ()
    }
  }
}

//----------------------------------------------------------
// Channel status.
//----------------------------------------------------------
DEFINE_FUNCTION moduleFB ()
{
//-- Power -------------------------
  [vdvAPI,POWER_FB] = (uState.bPwr = TRUE)

//-- InpSel ------------------------
  [vdvAPI,INPSEL01] = (uState.nInpSel = 1 )
  [vdvAPI,INPSEL02] = (uState.nInpSel = 2 )
  [vdvAPI,INPSEL03] = (uState.nInpSel = 3 )
  [vdvAPI,INPSEL04] = (uState.nInpSel = 4 )
  [vdvAPI,INPSEL05] = (uState.nInpSel = 5 )
  [vdvAPI,INPSEL06] = (uState.nInpSel = 6 )
  [vdvAPI,INPSEL07] = (uState.nInpSel = 7 )
  [vdvAPI,INPSEL08] = (uState.nInpSel = 8 )
  [vdvAPI,INPSEL09] = (uState.nInpSel = 9 )
  [vdvAPI,INPSEL10] = (uState.nInpSel = 10)

//-- VOL_LVL -----------------------
  [vdvAPI,VOL_MUTE_FB] = (uVol[1].uLvl.bMuted = TRUE)
  SEND_LEVEL vdvAPI, VOL_LVL, uVol[1].uLvl.snValue
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Device Components (i.e. uState) ------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Power
//----------------------------------------------------------
DEFINE_FUNCTION pwrOn ()
{
  uState.bPwr = TRUE
  SEND_COMMAND vdvAPI,"'PWR-ON,',ITOA (uProp.nPonDelay)"
  moduleFB ()

  sendTo ('PWR-ON', "'PWR-ON',13", uProp.nPonDelay*1000)
}

DEFINE_FUNCTION pwrOff ()
{
  uState.bPwr = FALSE
  SEND_COMMAND vdvAPI,"'PWR-OFF,',ITOA (uProp.nPofDelay)"
  moduleFB ()

  sendTo ('PWR-OFF', "'PWR-OFF',13", uProp.nPofDelay*1000)
}

DEFINE_FUNCTION pwrToggle ()
{
  IF(uState.bPwr = TRUE)  pwrOff ()
  ELSE                    pwrOn  ()
}

DEFINE_FUNCTION pwrOnMacro (CHAR cSrc[])
{
  IF(uState.bPwr <> TRUE) {
    pwrOn ()
  }

  inpSelAlias (cSrc)

  moduleFB ()
}


//----------------------------------------------------------
// Input Select
//----------------------------------------------------------
DEFINE_FUNCTION inpSel (INTEGER nIdx)
{
  SWITCH(nIdx)
  {
    CASE 1  : inpSelAlias ('HDMI1')
    CASE 2  : inpSelAlias ('HDMI2')
    DEFAULT : RETURN;
  }
}

DEFINE_FUNCTION inpSelAlias (CHAR cInp[])
STACK_VAR
  INTEGER nIdx
  CHAR    cData[50]
{
  SWITCH(UPPER_STRING(cInp))
  {
    CASE 'HDMI1' : {  nIdx = 1  cData = "'SRC-HDMI1',13" }
    CASE 'HDMI2' : {  nIdx = 2  cData = "'SRC-HDMI2',13" }
    DEFAULT      : RETURN;
  }

  uState.cInpSel = cInp
  uState.nInpSel = nIdx
  SEND_COMMAND vdvAPI,"'INPUTSELECT-',ITOA (uState.nInpSel),',',uState.cInpSel"

  sendTo ("'INP_SEL-',cInp", "cData", 1000)
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Containers ---------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Volume Level
//----------------------------------------------------------
DEFINE_FUNCTION volLvlSet (INTEGER nIdx, SINTEGER snValue)
{
  IF((nIdx = 0) || (nIdx > VOL_CNT))
    RETURN;

  IF(lvlSet (uVol[nIdx].uLvl, snValue)) {
    SEND_COMMAND vdvAPI,"'VOL_LVL-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snValue),',',ITOA (uVol[nIdx].uLvl.nBG)"
    sendTo ("'VOL_LVL-',ITOA(nIdx)", "'VOL_LVL-',ITOA (uVol[nIdx].uLvl.snValue),13", 200)

    IF(nIdx = 1)
      moduleFB ()
  }
}

DEFINE_FUNCTION volLvlStep (INTEGER nIdx, SINTEGER snStep)
{
  IF((nIdx = 0) || (nIdx > VOL_CNT))
    RETURN;

  lvlStep   (uVol[nIdx].uLvl, snStep)
  volLvlSet (nIdx, uVol[nIdx].uLvl.snValue)
}

DEFINE_FUNCTION volMuteOn (INTEGER nIdx)
{
  IF((nIdx = 0) || (nIdx > VOL_CNT))
    RETURN;

  uVol[nIdx].uLvl.bMuted = TRUE
  SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',ON'"

  IF(nIdx = 1)
    moduleFB ()

  sendTo ("'VOL_MUTE-',ITOA(nIdx),',ON'", "'VOL_MUTE-ON',13", 200)
}

DEFINE_FUNCTION volMuteOff (INTEGER nIdx)
{
  IF((nIdx = 0) || (nIdx > VOL_CNT))
    RETURN;

  uVol[nIdx].uLvl.bMuted = FALSE
  SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',OFF'"

  IF(nIdx = 1)
    moduleFB ()

  sendTo ("'VOL_MUTE-',ITOA(nIdx),',OFF'", "'VOL_MUTE-OFF',13", 200)
}

DEFINE_FUNCTION volMuteToggle (INTEGER nIdx)
{
  IF((nIdx = 0) || (nIdx > VOL_CNT))
    RETURN;

  IF(uVol[nIdx].uLvl.bMuted)  volMuteOff (nIdx)
  ELSE                        volMuteOn  (nIdx)
}


//----------------------------------------------------------
// Route an input to output.
//----------------------------------------------------------
DEFINE_FUNCTION route (INTEGER nIdx, INTEGER nInp, INTEGER nOut)
{
  IF((nIdx = 0) || (nIdx > RTR_CNT))
    RETURN;

  IF((nOut = 0) || (nOut > uRtr[nIdx].nOutCnt))
    RETURN;

  IF(nInp > uRtr[nIdx].nInpCnt)
    RETURN;

  uRtr[nIdx].nOut[nOut] = nInp
  uRtr[nIdx].nVidOut[nOut] = nInp
  uRtr[nIdx].nAudOut[nOut] = nInp
  SEND_COMMAND vdvAPI,"'ROUTE-',ITOA(nIdx),',',ITOA(nInp),',',ITOA(nOut)"

  sendTo ("'ROUTE-',ITOA(nIdx)", "'ROUTE-',ITOA(nInp),',',ITOA(nOut),13", 200)
}

DEFINE_FUNCTION routeVideo (INTEGER nIdx, INTEGER nInp, INTEGER nOut)
{
  IF((nIdx = 0) || (nIdx > RTR_CNT))
    RETURN;

  IF((nOut = 0) || (nOut > uRtr[nIdx].nOutCnt))
    RETURN;

  IF(nInp > uRtr[nIdx].nInpCnt)
    RETURN;

  uRtr[nIdx].nVidOut[nOut] = nInp
  SEND_COMMAND vdvAPI,"'ROUTE_VIDEO-',ITOA(nIdx),',',ITOA(nInp),',',ITOA(nOut)"

  sendTo ("'ROUTE_VIDEO-',ITOA(nIdx)", "'ROUTE_VIDEO-',ITOA(nInp),',',ITOA(nOut),13", 200)
}

DEFINE_FUNCTION routeAudio (INTEGER nIdx, INTEGER nInp, INTEGER nOut)
{
  IF((nIdx = 0) || (nIdx > RTR_CNT))
    RETURN;

  IF((nOut = 0) || (nOut > uRtr[nIdx].nOutCnt))
    RETURN;

  IF(nInp > uRtr[nIdx].nInpCnt)
    RETURN;

  uRtr[nIdx].nAudOut[nOut] = nInp
  SEND_COMMAND vdvAPI,"'ROUTE_AUDIO-',ITOA(nIdx),',',ITOA(nInp),',',ITOA(nOut)"

  sendTo ("'ROUTE_AUDIO-',ITOA(nIdx)", "'ROUTE_AUDIO-',ITOA(nInp),',',ITOA(nOut),13", 200)
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Parser helpers ------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------
// Parse reply.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR parseReply ()
{
  SELECT
  {
    ACTIVE(FIND_STRING(uBuff.cReply,"'OK'",1)) :
    {
    }
    ACTIVE(FIND_STRING(uBuff.cReply,"'ERR'",1)) :
    {
    }
    ACTIVE(FIND_STRING(uBuff.cReply,"'WAIT'",1)) :
    {
    }
  //----------------
  // Heartbeat
  //----------------
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'HEARTBEAT'",1)) :
    {
      uComm.nHeartbeatCounter = 0
    }
  //----------------
  // Power
  //----------------
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'?PWR'",1)) :
    {
      STACK_VAR CHAR bPwrPrev

      bPwrPrev = uState.bPwr

      SELECT
      {
        ACTIVE(FIND_STRING(uBuff.cReply,'PON',1)) : uState.bPwr = TRUE
        ACTIVE(FIND_STRING(uBuff.cReply,'POF',1)) : uState.bPwr = FALSE
      }

      IF(bPwrPrev <> uState.bPwr) {
        IF(uState.bPwr = TRUE)  SEND_COMMAND vdvAPI,'PWR-ON'
        ELSE                    SEND_COMMAND vdvAPI,'PWR-OFF'
      }
    }
  //----------------
  // InpSel
  //----------------
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'?INP_SEL'",1)) :
    {
      STACK_VAR INTEGER nInpSelPrev

      nInpSelPrev = uState.nInpSel

      SELECT
      {
        ACTIVE(FIND_STRING(uBuff.cReply,'HDMI1',1)) : { uState.nInpSel = 1  uState.cInpSel = 'HDMI1' }
        ACTIVE(FIND_STRING(uBuff.cReply,'HDMI2',1)) : { uState.nInpSel = 2  uState.cInpSel = 'HDMI2' }
        ACTIVE(1) : { uState.nInpSel = 0  uState.cInpSel = 'UNKNOWN' }
      }

      IF(nInpSelPrev <> uState.nInpSel)
        SEND_COMMAND vdvAPI,"'INPUTSELECT-',ITOA (uState.nInpSel),',',uState.cInpSel"
    }
  //----------------
  // Volume
  //----------------
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'?VOL_LVL'",1)) :
    {
      STACK_VAR  INTEGER nIdx
      STACK_VAR SINTEGER snValue
      STACK_VAR SINTEGER snValuePrev

      nIdx = 1
      snValuePrev = uVol[nIdx].uLvl.snValue
      snValue = ATOI (uBuff.cReply)

      SELECT
      {
        ACTIVE(snValue < uVol[nIdx].uLvl.snMin) : snValue = uVol[nIdx].uLvl.snMin
        ACTIVE(snValue > uVol[nIdx].uLvl.snMax) : snValue = uVol[nIdx].uLvl.snMax
      }
      uVol[nIdx].uLvl.snValue = snValue
      uVol[nIdx].uLvl.nBG     = snValueToBG (snValue, uVol[nIdx].uLvl.snMin, uVol[nIdx].uLvl.snMax)

      IF(snValuePrev <> uVol[nIdx].uLvl.snValue)
        SEND_COMMAND vdvAPI,"'VOL_LVL-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snValue),',',ITOA (uVol[nIdx].uLvl.nBG)"
    }
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'?VOL_MUTE'",1)) :
    {
      STACK_VAR  INTEGER nIdx
      STACK_VAR  CHAR bMutedPrev

      nIdx = 1
      bMutedPrev = uVol[nIdx].uLvl.bMuted

      SELECT
      {
        ACTIVE(FIND_STRING(uBuff.cReply,'ON' ,1)) : uVol[nIdx].uLvl.bMuted = TRUE
        ACTIVE(FIND_STRING(uBuff.cReply,'OFF',1)) : uVol[nIdx].uLvl.bMuted = FALSE
      }

      IF(bMutedPrev <> uVol[nIdx].uLvl.bMuted) {
        IF(uVol[nIdx].uLvl.bMuted = TRUE)  SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',ON'"
        ELSE                               SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',OFF'"
      }
    }
  //----------------
  // Router
  //----------------
    ACTIVE(FIND_STRING(uQue.uLastItem.cAlias,"'?ROUTE'",1)) :
    {
      STACK_VAR INTEGER nIdx
      STACK_VAR INTEGER nInp
      STACK_VAR INTEGER nOut

      nIdx = 1
      nInp = 0
      nOut = 0

      IF(nOut && (nOut <= uRtr[nIdx].nOutCnt)) {
        STACK_VAR INTEGER nOutPrev

        nOutPrev = uRtr[nIdx].nOut[nOut]

        uRtr[nIdx].nOut[nOut] = nInp

        IF(nOutPrev <> uRtr[nIdx].nOut[nOut]) {
          SEND_COMMAND vdvAPI,"'ROUTE-',ITOA(nIdx),',',ITOA(nInp),',',ITOA(nOut)"
        }
      }
    }
  //----------------
  // Unhandled
  //----------------
    ACTIVE(1) : {
      RETURN (FALSE)
    }
  }

  RETURN (TRUE)
}

//-----------------------------------------------------------
// Parse buffer.
//-----------------------------------------------------------
DEFINE_FUNCTION parseBuffer ()
STACK_VAR
  INTEGER nCount
{
  WHILE(FIND_STRING(uBuff.cBuff,"13",1)) {
  //-- Get a complete reply --------
    uBuff.cReply = REMOVE_STRING(uBuff.cBuff,"13",1)

  //-- Is cReply big enough? -------
    IF((LENGTH_STRING(uBuff.cReply) = 0) && FIND_STRING(uBuff.cBuff,"13",1)) {
      uBuff.cBuff = ""
      log (AMX_ERROR, 'parseBuffer()', "'cReply NOT big enough!  cBuff being reset!'")
      BREAK;
    }

  //-- Need complete reply ---------
    IF(!LENGTH_STRING(uBuff.cReply))
      BREAK;

  //-- Echo ------------------------
    IF(uComm.bEchoRX) {
      echoRx ("uQue.uLastItem.cAlias", "uBuff.cReply")
    }

  //-- Parse this reply ------------
    IF(parseReply () = TRUE) {
      ON[vdvAPI,DEVICE_COMMUNICATING]
      uComm.nPollCounter = 0
      nCount++
    }
  }

  IF(nCount)
    moduleFB ()
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Interface helpers --------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Build the virtual interface.
//----------------------------------------------------------
DEFINE_FUNCTION buildInterface ()
{
//-- Expand channels ---------------
  SET_VIRTUAL_CHANNEL_COUNT (vdvMAIN, VCHN_CNT)
  SET_VIRTUAL_CHANNEL_COUNT (vdvAPI , VCHN_CNT)

//-- Expand levels -----------------
  SET_VIRTUAL_LEVEL_COUNT   (vdvMAIN, VLVL_CNT)
  SET_VIRTUAL_LEVEL_COUNT   (vdvAPI , VLVL_CNT)

//-- No echo -----------------------
  TRANSLATE_DEVICE (vdvMAIN, vdvAPI)
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Misc helpers -------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------


//==============================================================================
// Start
//==============================================================================
DEFINE_START

//-- Print version -----------------------------------------
cDevNum = "ITOA (dvDEV.NUMBER),':',ITOA (dvDEV.PORT),':',ITOA (dvDEV.SYSTEM)"
SEND_STRING 0,"'Running ',cMDL_NAME,' (',__LDATE__,'@',__TIME__,') v0.0.0 for ',cDevNum"


//-- Static Properties -------------------------------------
uProp.cMake         = '<make>'
uProp.cModel        = '<model>'
uProp.cAssetType    = '<assetType>'


//-- Dynamic Property Defaults -----------------------------
uProp.uIP.URL       = ''
uProp.uIP.Port      = 23
uProp.uIP.User      = ''
uProp.uIP.Password  = ''

uProp.nPonDelay     = 5
uProp.nPofDelay     = 10
uProp.nPollDelay    = 5
uProp.nIpOpenDelay  = 5


//-- Interface ---------------------------------------------
buildInterface ()


//-- Driver ------------------------------------------------
moduleInit ()


//==============================================================================
// Events
//==============================================================================
DEFINE_EVENT

//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Initialization -----------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Real device
//----------------------------------------------------------
DATA_EVENT[dvDEV]
{
  ONLINE :
  {
    uComm.cConnectionState = 'ONLINE'
    uComm.bConnected  = TRUE

  //-- 232 Settings ----------------
    IF(DATA.DEVICE.NUMBER > 0) {
      SEND_COMMAND DATA.DEVICE,'SET BAUD 9600,N,8,1 485 DISABLE'
      SEND_COMMAND DATA.DEVICE,'HSOFF'
      SEND_COMMAND DATA.DEVICE,'CHARD-0'
      queReset ()
    }

  //-- Heartbeat -------------------
    sendHeartbeat  ()
    heartbeatStart ()

  //-- Polling ---------------------
    IF(uProp.nPollDelay) {
      sendHeartbeat ()
      pollStart ()
    }

  //-- Que -------------------------
    queCheck ()
  }
  OFFLINE :
  {
    uComm.cConnectionState = 'OFFLINE'
    uComm.bConnected  = FALSE

  //-- Lost comm -------------------
    OFF[vdvAPI,DEVICE_COMMUNICATING]
    OFF[vdvAPI,DATA_INITIALIZED]

  //-- Reconnect IP ----------------
    IF(queHasItems ()) {
      STACK_VAR LONG lTlTimes[1]

      uComm.cConnectionState = 'WAITING'
      lTlTimes[1] = uProp.nIpOpenDelay * 1000
      TIMELINE_CREATE(TL_IP_RECONNECT, lTlTimes, 1, TIMELINE_RELATIVE, TIMELINE_ONCE)
    }
  }
  ONERROR :
  {
    IF(uComm.cConnectionState = 'CONNECTING') {
      STACK_VAR LONG lTlTimes[1]

      uComm.cConnectionState = 'WAITING'
      lTlTimes[1] = uProp.nIpOpenDelay * 1000
      TIMELINE_CREATE(TL_IP_RECONNECT, lTlTimes, 1, TIMELINE_RELATIVE, TIMELINE_ONCE)
    }

    SWITCH(DATA.NUMBER)
    {
      CASE  2 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 2: SOCKET_OPEN_FAILED  General failure (out of memory)'")
      CASE  3 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 3: ILLEGAL_INTERNET_ADDRESS'")
      CASE  4 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 4: UNKNOWN_HOST  Host name is not resolvable to a physical host'")
      CASE  6 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 6: CONNECTION_REFUSED  Host does not have a server listening'")
      CASE  7 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 7: CONNECTION_TIMEOUT  Host has not replied within a reasonable time'")
      CASE  8 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 8: UNKNOWN_CONNECT_ERROR  Some other undefined error has occurred'")
      CASE  9 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 9: SOCKET_ALREADY_CLOSED  Connection is already closed'")
      CASE 12 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 12: SOCKET_NOT_CONNECTED Cannot send data on a socket that is not connected'")
      CASE 13 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 13: UNKNOWN_SENDTO_ERROR Tried sending data on a UDP socket that has failed to open'")
      CASE 14 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 14: LOCAL_PORT_ALREADY_ASSIGNED  Local port already used'")
      CASE 16 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 16: TOO_MANY_OPEN_SOCKETS  Too many open sockets, limited to 200'")
      CASE 17 : log (AMX_ERROR, 'ONERROR', "'[',cDevNum, '] ERR 17: LOCAL_PORT_NOT_OPEN  Local Port (D:P:S) is not open'")
    }
  }
  STRING :
  {
    uBuff.cBuff = "uBuff.cBuff,DATA.TEXT"

    parseBuffer()
  }
}

//----------------------------------------------------------
// Virtual interface
//----------------------------------------------------------
DATA_EVENT[vdvAPI]
{
  COMMAND :
  {
    STACK_VAR CHAR         cCmd[DUET_MAX_CMD_LEN]
    STACK_VAR CHAR      cHeader[DUET_MAX_HDR_LEN]
    STACK_VAR CHAR    cParam[3][DUET_MAX_PARAM_LEN]
    STACK_VAR INTEGER nIdx

    cCmd      = DATA.TEXT
    cHeader   = DuetParseCmdHeader(cCmd)
  	cParam[1] = DuetParseCmdParam (cCmd)
  	cParam[2] = DuetParseCmdParam (cCmd)
  	cParam[3] = DuetParseCmdParam (cCmd)

  	IF(cParam[1] = '-2147483648')  cParam[1] = ''
  	IF(cParam[2] = '-2147483648')  cParam[2] = ''
  	IF(cParam[3] = '-2147483648')  cParam[3] = ''
  	nIdx = ATOI(cParam[1])

    SWITCH(UPPER_STRING(cHeader))
    {
    //------------------------------
    //-- Properties
    //------------------------------
      CASE '?DEV_INFO' : {
        SEND_COMMAND vdvAPI,"'DEV_INFO-Make,',uProp.cMake"
        SEND_COMMAND vdvAPI,"'DEV_INFO-Model,',uProp.cModel"
        SEND_COMMAND vdvAPI,"'DEV_INFO-AssetType,',uProp.cAssetType"
      }
      CASE '?PROPERTIES' : {
      //-- Misc ------------------
        SEND_COMMAND vdvAPI,"'PROPERTY-POLL_TIME,',ITOA (uProp.nPollDelay)"
        SEND_COMMAND vdvAPI,"'PROPERTY-RECONNECT_TIME,',ITOA (uProp.nIpOpenDelay)"

      //-- IP Comm ---------------
        SEND_COMMAND vdvAPI,"'PROPERTY-IP_ADDRESS,',uProp.uIP.URL"
        SEND_COMMAND vdvAPI,"'PROPERTY-PORT,',ITOA (uProp.uIP.Port)"
        SEND_COMMAND vdvAPI,"'PROPERTY-USER_NAME,',uProp.uIP.User"
        SEND_COMMAND vdvAPI,"'PROPERTY-PASSWORD,',uProp.uIP.Password"

      //-- Capabilities ----------
        SEND_COMMAND vdvAPI,"'PROPERTY-HAS-POWER'"
        SEND_COMMAND vdvAPI,"'PROPERTY-HAS-INPUT-SELECT'"
        SEND_COMMAND vdvAPI,"'PROPERTY-HAS-VOLUME,',ITOA(VOL_CNT)"
        SEND_COMMAND vdvAPI,"'PROPERTY-HAS-ROUTER,',ITOA(RTR_CNT)"
      }
      CASE '?PROPERTY' : {
        SWITCH(UPPER_STRING(cParam[1]))
        {
        //-- Misc ------------------
          CASE 'POLL_TIME'      : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',ITOA (uProp.nPollDelay)"
          CASE 'RECONNECT_TIME' : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',ITOA (uProp.nIpOpenDelay)"

        //-- IP Comm ---------------
          CASE 'IP_ADDRESS' : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',uProp.uIP.URL"
          CASE 'PORT'       : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',ITOA (uProp.uIP.Port)"
          CASE 'USER_NAME'  : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',uProp.uIP.User"
          CASE 'PASSWORD'   : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',uProp.uIP.Password"

        //-- Capabilities ----------
          CASE 'HAS-POWER'         : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1]"
          CASE 'HAS-INPUT-SELECT'  : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1]"
          CASE 'HAS-VOLUME'        : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',ITOA(VOL_CNT)"
          CASE 'HAS-ROUTER'        : SEND_COMMAND vdvAPI,"'PROPERTY-',cParam[1],',',ITOA(RTR_CNT)"
        }
      }
      CASE 'PROPERTY' : {
        SWITCH(UPPER_STRING(cParam[1]))
        {
        //-- Misc ------------------
          CASE 'POLL_TIME'      : uProp.nPollDelay   = ATOI (cParam[2])
          CASE 'RECONNECT_TIME' : uProp.nIpOpenDelay = ATOI (cParam[2])

        //-- IP Comm ---------------
          CASE 'IP_ADDRESS' : uProp.uIP.URL      = cParam[2]
          CASE 'PORT'       : uProp.uIP.Port     = ATOI (cParam[2])
          CASE 'USER_NAME'  : uProp.uIP.User     = cParam[2]
          CASE 'PASSWORD'   : uProp.uIP.Password = cParam[2]
        }
      }
    //------------------------------
    //-- Module
    //------------------------------
      CASE 'REINIT' : {
        moduleReinit ()
      }
      CASE 'PASSTHRU' : {
        STACK_VAR LONG lDelay

      //-- Optional Alias ----------
        IF(!LENGTH_STRING(cParam[2]))
          cParam[2] = 'PASSTHRU'

      //-- Optional lDelay ---------
        lDelay = ATOI (cParam[3])

      //-- Add delimiter -----------
        IF(!FIND_STRING(cParam[1],"13",1))
          cParam[1] = "cParam[1],13"

        sendTo (cParam[2], cParam[1], lDelay)
      }
    //------------------------------
    //-- Communication
    //------------------------------
      CASE '?COMM' : {
        SEND_STRING 0,"'COMM-',cDevNum"
        SEND_STRING 0,"'    ONLINE:',snapiGetBooleanString (uComm.bConnected)"
        SEND_STRING 0,"'    CONNECTION_STATE:',uComm.cConnectionState"
        SEND_STRING 0,"'    DATA_INITIALIZED:',snapiGetBooleanChannel ([vdvMAIN,DATA_INITIALIZED])"
        SEND_STRING 0,"'    DEVICE_COMMUNICATING:',snapiGetBooleanChannel ([vdvMAIN,DEVICE_COMMUNICATING])"
        SEND_STRING 0,"'    PROPERTY-POLL_TIME,',ITOA (uProp.nPollDelay)"
        IF(dvDEV.NUMBER = 0) {
          SEND_STRING 0,"'    PROPERTY-IP_ADDRESS,',uProp.uIP.URL"
          SEND_STRING 0,"'    PROPERTY-PORT,',ITOA (uProp.uIP.PORT)"
          SEND_STRING 0,"'    PROPERTY-RECONNECT_TIME,',ITOA (uProp.nIpOpenDelay)"
        }
      }
      CASE 'IP_OPEN' : {
        STACK_VAR CHAR cParamsEXT[2][DUET_MAX_PARAM_LEN]

      //-- URL ---------------------
        uProp.uIP.URL  = cParam[1]

      //-- Optional Port -----------
        IF(LENGTH_STRING(cParam[2]))
          uProp.uIP.Port = ATOI(cParam[2])

      //-- Optional User/PW --------
      	cParamsEXT[1] = cParam[3]
      	cParamsEXT[2] = DuetParseCmdParam (cCmd)

        IF(LENGTH_STRING(cParamsEXT[1]))
          uProp.uIP.User = cParamsEXT[1]

        IF(LENGTH_STRING(cParamsEXT[2]))
          uProp.uIP.Password = cParamsEXT[2]

        moduleReinit ()
      }
      CASE 'IP_CLOSE' : {
        ipClose ()
      }
    //------------------------------
    //-- Power
    //------------------------------
      CASE '?PWR' : {
        SWITCH(uState.bPwr)
        {
          CASE TRUE  : SEND_COMMAND vdvAPI,"'PWR-ON'"
          CASE FALSE : SEND_COMMAND vdvAPI,"'PWR-OFF'"
          DEFAULT    : SEND_COMMAND vdvAPI,"'PWR-UNKNOWN'"
        }
      }
      CASE 'PWR' : {
        SWITCH(UPPER_STRING(cParam[1]))
        {
          CASE 'ON'  : pwrOn  ()
          CASE 'OFF' : pwrOff ()
          CASE 'TGL' : pwrToggle ()
          CASE 'MACRO' : pwrOnMacro (UPPER_STRING(cParam[2]))
        }
      }
      CASE '?WARMUP' : {
        SEND_COMMAND vdvAPI,"'WARMUP-',ITOA (uProp.nPonDelay)"
      }
      CASE 'WARMUP' : {
        uProp.nPonDelay = ATOI (cParam[1])
      }
      CASE '?COOLDOWN' : {
        SEND_COMMAND vdvAPI,"'COOLDOWN-',ITOA (uProp.nPofDelay)"
      }
      CASE 'COOLDOWN' : {
        uProp.nPofDelay = ATOI (cParam[1])
      }
    //------------------------------
    //-- InpSel
    //------------------------------
      CASE '?INPUTSELECT' : {
        SEND_COMMAND vdvAPI,"'INPUTSELECT-',ITOA (uState.nInpSel),',',uState.cInpSel"
      }
      CASE 'INPUTSELECT' : {
        inpSel (ATOI (cParam[1]))
      }
      CASE 'INPUTSELECT_ALIAS' : {
        SWITCH(UPPER_STRING(cParam[1]))
        {
          CASE 'HDMI1' : inpSelAlias (cParam[1])
          CASE 'HDMI2' : inpSelAlias (cParam[1])
        }
      }
      CASE '?INPUTCOUNT' : {
        SEND_COMMAND vdvAPI,"'INPUTCOUNT-2'"
      }
      CASE '?INPUTPROPERTIES' : {   // <index>,<inputGroup>,<signalType>,<deviceLabel>,<displayName>
        SEND_COMMAND vdvAPI,"'INPUTPROPERTY-1,0,HDMI,HDMI1,HDMI1'"
        SEND_COMMAND vdvAPI,"'INPUTPROPERTY-2,0,HDMI,HDMI2,HDMI2'"
      }
      CASE '?INPUTPROPERTY' : {
        SWITCH(ATOI (cParam[1]))
        {
          CASE 1 : SEND_COMMAND vdvAPI,"'INPUTPROPERTY-1,0,HDMI,HDMI1,HDMI1'"
          CASE 2 : SEND_COMMAND vdvAPI,"'INPUTPROPERTY-2,0,HDMI,HDMI2,HDMI2'"
        }
      }
    //------------------------------
    //-- Volume Level
    //------------------------------
      CASE '?VOL_LVL_COUNT' : {
        SEND_COMMAND vdvAPI,"'VOL_LVL_COUNT-',ITOA(VOL_CNT)"
      }
      CASE '?VOL_LVL_RANGE' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          SEND_COMMAND vdvAPI,"'VOL_LVL_RANGE-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snMin),',',ITOA (uVol[nIdx].uLvl.snMax)"
        }
      }
      CASE 'VOL_LVL_RANGE' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          STACK_VAR SINTEGER snMin
          STACK_VAR SINTEGER snMax

          snMin = ATOI(cParam[2])
          snMax = ATOI(cParam[3])

        //-- Assign range ----------
          uVol[nIdx].uLvl.snMin = snMin
          uVol[nIdx].uLvl.snMax = snMax

        //-- Get in-range ----------
          IF(snValueInRange (uVol[nIdx].uLvl.snValue, uVol[nIdx].uLvl.snMin, uVol[nIdx].uLvl.snMax) = FALSE) {
            IF(uVol[nIdx].uLvl.snValue < uVol[nIdx].uLvl.snMin)
              uVol[nIdx].uLvl.snValue = uVol[nIdx].uLvl.snMin
            ELSE IF(uVol[nIdx].uLvl.snValue > uVol[nIdx].uLvl.snMax)
              uVol[nIdx].uLvl.snValue = uVol[nIdx].uLvl.snMax

            uVol[nIdx].uLvl.nBG = snValueToBG (uVol[nIdx].uLvl.snValue, uVol[nIdx].uLvl.snMin, uVol[nIdx].uLvl.snMax)
            SEND_COMMAND vdvAPI,"'VOL_LVL-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snValue),',',ITOA (uVol[nIdx].uLvl.nBG)"
          }


          SEND_COMMAND vdvAPI,"'VOL_LVL_RANGE-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snMin),',',ITOA (uVol[nIdx].uLvl.snMax)"
        }
      }
      CASE '?VOL_LVL' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          SEND_COMMAND vdvAPI,"'VOL_LVL-',ITOA(nIdx),',',ITOA (uVol[nIdx].uLvl.snValue),',',ITOA (uVol[nIdx].uLvl.nBG)"
        }
      }
      CASE 'VOL_LVL' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          volLvlSet  (nIdx, ATOI (cParam[2]))
        }
      }
      CASE 'VOL_STEP' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          volLvlStep (nIdx, ATOI (cParam[2]))
        }
      }
      CASE '?VOL_MUTE' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          SWITCH(uVol[nIdx].uLvl.bMuted)
          {
            CASE TRUE  : SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',ON'"
            CASE FALSE : SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',OFF'"
            DEFAULT    : SEND_COMMAND vdvAPI,"'VOL_MUTE-',ITOA(nIdx),',UNKNOWN'"
          }
        }
      }
      CASE 'VOL_MUTE' : {
        IF(nIdx && (nIdx <= VOL_CNT)) {
          SWITCH(UPPER_STRING(cParam[2]))
          {
            CASE 'ON'  : volMuteOn  (nIdx)
            CASE 'OFF' : volMuteOff (nIdx)
            CASE 'TGL' : volMuteToggle (nIdx)
          }
        }
      }
    //------------------------------
    //-- Router
    //------------------------------
      CASE '?ROUTER_SIZE' : {
        IF(nIdx && (nIdx <= RTR_CNT)) {
          SEND_COMMAND vdvAPI,"'ROUTER_SIZE-',ITOA(nIdx),',',ITOA(uRtr[nIdx].nInpCnt),',',ITOA(uRtr[nIdx].nOutCnt)"
        }
      }
      CASE 'ROUTER_SIZE' : {
        IF(nIdx && (nIdx <= RTR_CNT)) {
          STACK_VAR INTEGER nInp
          STACK_VAR INTEGER nOut

          nInp = ATOI (cParam[2])
          nOut = ATOI (cParam[3])

          IF(nInp && (nInp <= RTR_INP_MAX))
            uRtr[nIdx].nInpCnt = nInp

          IF(nOut && (nOut <= RTR_OUT_MAX))
            uRtr[nIdx].nOutCnt = nOut

          SEND_COMMAND vdvAPI,"'ROUTER_SIZE-',ITOA(nIdx),',',ITOA(uRtr[nIdx].nInpCnt),',',ITOA(uRtr[nIdx].nOutCnt)"
        }
      }
      CASE '?ROUTE_VIDEO' :
      CASE '?ROUTE_AUDIO' :
      CASE '?ROUTE'       : {
        IF(nIdx && (nIdx <= RTR_CNT)) {
          STACK_VAR INTEGER nLoop

          FOR(nLoop=1; nLoop<=uRtr[nIdx].nOutCnt; nLoop++) {
            SWITCH(UPPER_STRING(cHeader))
            {
              CASE '?ROUTE_VIDEO' : SEND_COMMAND vdvAPI,"'ROUTE_VIDEO-',ITOA(nIdx),',',ITOA(uRtr[nIdx].nVidOut[nLoop]),',',ITOA(nLoop)"
              CASE '?ROUTE_AUDIO' : SEND_COMMAND vdvAPI,"'ROUTE_AUDIO-',ITOA(nIdx),',',ITOA(uRtr[nIdx].nAudOut[nLoop]),',',ITOA(nLoop)"
              CASE '?ROUTE'       : SEND_COMMAND vdvAPI,"      'ROUTE-',ITOA(nIdx),',',ITOA(uRtr[nIdx].nOut[nLoop]),   ',',ITOA(nLoop)"
            }
          }
        }
      }
      CASE 'ROUTE_VIDEO' :
      CASE 'ROUTE_AUDIO' :
      CASE 'ROUTE'       : {
        IF(nIdx && (nIdx <= RTR_CNT)) {
          STACK_VAR INTEGER nInp
          STACK_VAR INTEGER nOut

          nInp = ATOI (cParam[2])
          nOut = ATOI (cParam[3])

          SWITCH(UPPER_STRING(cHeader))
          {
            CASE 'ROUTE_VIDEO' : routeVideo (nIdx, nInp, nOut)
            CASE 'ROUTE_AUDIO' : routeAudio (nIdx, nInp, nOut)
            CASE 'ROUTE'       : route (nIdx, nInp, nOut)
          }
        }
      }
      CASE 'ROUTE_VIDEO_MANY' :
      CASE 'ROUTE_AUDIO_MANY' :
      CASE 'ROUTE_MANY'       : {
        IF(nIdx && (nIdx <= RTR_CNT)) {
          STACK_VAR INTEGER nInp
          STACK_VAR INTEGER nOut
          STACK_VAR INTEGER nLoop

          nInp = ATOI (cParam[2])

          WHILE(LENGTH_STRING(cParam[3])) {
            IF(FIND_STRING(cParam[3],',',1)) {
              nOut = ATOI(REMOVE_STRING(cParam[3],',',1))
            }
            ELSE {
              nOut = ATOI(cParam[3])
              cParam[3] = ''
            }

            SWITCH(UPPER_STRING(cHeader))
            {
              CASE 'ROUTE_VIDEO_MANY' : routeVideo (nIdx, nInp, nOut)
              CASE 'ROUTE_AUDIO_MANY' : routeAudio (nIdx, nInp, nOut)
              CASE 'ROUTE_MANY'       : route (nIdx, nInp, nOut)
            }
          }
        }
      }
    }
  }
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Virtual Interfaces -------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Power
//----------------------------------------------------------
CHANNEL_EVENT[vdvAPI,POWER]
CHANNEL_EVENT[vdvAPI,PWR_ON]
CHANNEL_EVENT[vdvAPI,PWR_OFF]
{
  ON :
  {
    SWITCH(CHANNEL.CHANNEL)
    {
      CASE POWER   : pwrToggle ()
      CASE PWR_ON  :     pwrOn ()
      CASE PWR_OFF :    pwrOff ()
    }

    OFF[vdvMAIN,CHANNEL.CHANNEL]
  }
}

//----------------------------------------------------------
// InpSel
//----------------------------------------------------------
CHANNEL_EVENT[vdvAPI,INPSEL01]
CHANNEL_EVENT[vdvAPI,INPSEL02]
CHANNEL_EVENT[vdvAPI,INPSEL03]
CHANNEL_EVENT[vdvAPI,INPSEL04]
CHANNEL_EVENT[vdvAPI,INPSEL05]
CHANNEL_EVENT[vdvAPI,INPSEL06]
CHANNEL_EVENT[vdvAPI,INPSEL07]
CHANNEL_EVENT[vdvAPI,INPSEL08]
CHANNEL_EVENT[vdvAPI,INPSEL09]
CHANNEL_EVENT[vdvAPI,INPSEL10]
{
  ON :
  {
    inpSel (CHANNEL.CHANNEL-INPSEL01+1)

    OFF[vdvMAIN,CHANNEL.CHANNEL]
  }
}

//----------------------------------------------------------
// VOL_LVL
//----------------------------------------------------------
LEVEL_EVENT[vdvAPI,VOL_LVL]
{
  volLvlSet (1, LEVEL.VALUE)
}

CHANNEL_EVENT[vdvAPI,VOL_MUTE]
CHANNEL_EVENT[vdvAPI,VOL_MUTE_ON]
{
  ON  :
  {
    SWITCH(CHANNEL.CHANNEL)
    {
      CASE VOL_MUTE    : volMuteToggle (1)
      CASE VOL_MUTE_ON : volMuteOn     (1)
    }

    OFF[vdvMAIN,CHANNEL.CHANNEL]
  }
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Timelines ----------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Que timeout
//----------------------------------------------------------
TIMELINE_EVENT[TL_QUE]
{
  IF(TIMELINE.SEQUENCE = 1) {
    queExpired ()
  }
  ELSE {
    IF(queCheck () = FALSE) {
    //-- Should we ipClose()? ------
      SELECT
      {
        ACTIVE(dvDEV.NUMBER > 0)           : {}  // 232 Device
        ACTIVE(uComm.bConnected = FALSE)   : {}  // Not connected
        ACTIVE(queHasItems () = TRUE)      : {}  // Items pending
        ACTIVE(uProp.nPollDelay > 0)       : {}  // Keep polling
        ACTIVE(1) : {
          ipClose ()
        }
      }
    }
  }
}

//----------------------------------------------------------
// Heartbeat timeout
//----------------------------------------------------------
#IF_DEFINED TL_HEARTBEAT
  TIMELINE_EVENT[TL_HEARTBEAT]
  {
    sendHeartbeat ()

  //-- Comm lost -------------------
    uComm.nHeartbeatCounter++
    IF(uComm.nHeartbeatCounter > 3) {
      OFF[vdvAPI,DEVICE_COMMUNICATING]
      OFF[vdvAPI,DATA_INITIALIZED]
    }
  }
#END_IF

//----------------------------------------------------------
// Polling timeout
//----------------------------------------------------------
#IF_DEFINED TL_POLL
  TIMELINE_EVENT[TL_POLL]
  {
    IF(uProp.nPollDelay = 0) {
      pollStop ()
    }
    ELSE {
    //-- Device not on -------------
      IF(uState.bPwr <> TRUE) {
        uComm.nPollStep = 1
      }

    //-- Poll this -----------------
      SWITCH(uComm.nPollStep)
      {
        CASE 1 : sendTo ('?PWR'      ,"'POLL-PWR',13", 200)
        CASE 2 : sendTo ('?INP_SEL'  ,"'POLL-INP_SEL',13", 200)
        CASE 3 : sendTo ('?VID_MUTE' ,"'POLL-VID_MUTE',13", 200)
        CASE 4 : sendTo ('?VOL_MUTE' ,"'POLL-VOL_MUTE',13", 200)
        CASE 5 : sendTo ('?VOL_LVL ' ,"'POLL-VOL_LVL',13", 200)
        CASE 6 : sendTo ('?LAMP'     ,"'POLL-LAMP',13", 200)
      }


    //-- Poll step -----------------
      uComm.nPollStep++
      IF(uComm.nPollStep > 6) {
        uComm.nPollStep = 1

        IF([vdvMAIN,DEVICE_COMMUNICATING])
          ON[vdvAPI,DATA_INITIALIZED]
      }

    //-- Comm lost -----------------
      uComm.nPollCounter++
      IF(uComm.nPollCounter > 5) {
        OFF[vdvAPI,DEVICE_COMMUNICATING]
        OFF[vdvAPI,DATA_INITIALIZED]
      }
    }
  }
#END_IF

//----------------------------------------------------------
// IP reconnect timeout
//----------------------------------------------------------
#IF_DEFINED TL_IP_RECONNECT
  TIMELINE_EVENT[TL_IP_RECONNECT]
  {
    uComm.cConnectionState = 'RECONNECTING'
    ipOpen ()
  }
#END_IF

//----------------------------------------------------------
// Power countdown
//----------------------------------------------------------
#IF_DEFINED TL_COUNTER_PWR
  TIMELINE_EVENT[TL_COUNTER_PWR]
  {
    IF(uCounterPwr.nCount) {
      uCounterPwr.nCount--
      SEND_COMMAND vdvAPI,"uCounterPwr.cContext,'-',ITOA (uCounterPwr.nCount),',',ITOA (uCounterPwr.nStart)"
    }
    ELSE {
      TIMELINE_KILL(TIMELINE.ID)
      uCounterPwr.nStart   = 0
      uCounterPwr.cContext = ''
    }
  }
#END_IF


//==============================================================================
// End
//==============================================================================

