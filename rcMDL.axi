PROGRAM_NAME='rcMDL'
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
   Title    - rcMDL
   subTitle - Module helpers to quickly stand-up a device driver.


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
   - You should not need to modify this file.  If you do, it is
     recommended to keep logic out of this file, wherever possible.
   - The helper functions here are to be implemented by a driver module.
   - Mandatory timelines: TL_QUE
     - The driver is based upon commands flowing thru the que.
   - Optional timelines:  TL_POLL, TL_IP_RECONNECT, TL_COUNTER_PWR
     - The driver and rcMDL are designed to compile w/o them.


   Links:
  -----------------------------------
   -
-------------------------------------------------------------*/
#IF_NOT_DEFINED rcMDL
#DEFINE rcMDL


//==============================================================================
// SNAPI Emulation
//==============================================================================
INCLUDE 'SNAPI'


//==============================================================================
// Constants
//==============================================================================
DEFINE_CONSTANT

//-- Defaults ----------------------------------------------
#IF_NOT_DEFINED HEARTBEAT_DELAY
  LONG HEARTBEAT_DELAY = 30000
#END_IF


//==============================================================================
// Types
//==============================================================================
DEFINE_TYPE

//==============================================================================
// Variables
//==============================================================================
DEFINE_VARIABLE

//==============================================================================
// Functions
//==============================================================================

//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- IP helpers ---------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Open up an IP connection.
//----------------------------------------------------------
DEFINE_FUNCTION ipOpen ()
{
//-- Check for errors --------------
  IF(dvDEV.NUMBER > 0) {
    log (AMX_ERROR, 'ipOpen()', "'[',cDevNum,'] is not an IP device!'")
    RETURN;
  }

  IF(LENGTH_STRING(uProp.uIP.URL) = 0) {
    log (AMX_ERROR, 'ipOpen()', "'[',cDevNum,'] has no URL assignment!'")
    RETURN;
  }

//-- Can I open --------------------
  IF(uComm.bConnected) {
    log (AMX_INFO, 'ipOpen()', "'[',cDevNum,'] is already open!'")
    RETURN;
  }

  IF(uComm.cConnectionState = 'CONNECTING') {
    log (AMX_INFO, 'ipOpen()', "'[',cDevNum,'] is already attempting a connection!'")
    RETURN;
  }

  IF(uComm.cConnectionState = 'WAITING') {
    log (AMX_INFO, 'ipOpen()', "'[',cDevNum,'] is already waiting to reconnect!'")
    RETURN;
  }

//-- Whew, open it up --------------
  uComm.cConnectionState = 'CONNECTING'
  IP_CLIENT_OPEN (dvDEV.PORT, uProp.uIP.URL, uProp.uIP.Port, IP_TCP)
}

//----------------------------------------------------------
// Close an IP connection.
//----------------------------------------------------------
DEFINE_FUNCTION ipClose ()
{
//-- Check for errors --------------
  IF(dvDEV.NUMBER > 0) {
    log (AMX_ERROR, 'ipClose()', "'[',cDevNum,'] is not an IP device!'")
    RETURN;
  }
//-- Can I close -------------------
  IF(!uComm.bConnected) {
    RETURN;
  }

//-- Cancel connect ----------------
  IF(uComm.cConnectionState = 'CONNECTING') {
  }

//-- Cancel reconnect --------------
#IF_DEFINED TL_IP_RECONNECT
  IF(uComm.cConnectionState = 'WAITING') {
    TIMELINE_KILL(TL_IP_RECONNECT)
  }
#END_IF

//-- Whew, close it ----------------
  uComm.cConnectionState = ''
  IP_CLIENT_CLOSE (dvDEV.PORT)
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Que helpers --------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Add to device que.
//----------------------------------------------------------
DEFINE_FUNCTION queAdd (CHAR cAlias[], CHAR cData[], LONG lDelay)
{
//-- No duplicate queries ----------
  IF(FIND_STRING(cAlias,'?',1)) {
    IF(queFind (cAlias)) {
      RETURN;
    }
  }

//-- Look to clear it --------------
  SWITCH(cAlias)
  {
    CASE 'PWR-ON'  :
    CASE 'PWR-OFF' : queClear ()
  }

//-- Navigation --------------------
	uQue.nLast++
	IF(uQue.nLast > MAX_LENGTH_ARRAY(uQue.uItem))
		uQue.nLast = 1

//-- Put it here -------------------
	uQue.uItem[uQue.nLast].cAlias = cAlias
	uQue.uItem[uQue.nLast].cData  = cData
	uQue.uItem[uQue.nLast].lDelay = lDelay

//-- Maybe we can send it now ------
	queCheck ()
}

//----------------------------------------------------------
// Check to send from que.
//----------------------------------------------------------
DEFINE_FUNCTION CHAR queCheck ()
STACK_VAR
  LONG lTlTimes[2]
{
//-- Not Connected -----------------
  IF(!uComm.bConnected)
    RETURN (FALSE)

//-- Busy --------------------------
  IF(TIMELINE_ACTIVE(TL_QUE))
    RETURN (FALSE)

//-- Empty que ---------------------
  IF(!queHasItems ())
    RETURN (FALSE)

//-- Find next ---------------------
	WHILE(uQue.nCurrent <> uQue.nLast) {
		uQue.nCurrent++
		IF(uQue.nCurrent > MAX_LENGTH_ARRAY(uQue.uItem))
			uQue.nCurrent = 1

		IF(LENGTH_STRING(uQue.uItem[uQue.nCurrent].cData)) {
			uQue.uLastItem = uQue.uItem[uQue.nCurrent]
			BREAK
		}
	}

//-- Send it -----------------------
  SEND_STRING dvDEV,"uQue.uLastItem.cData"

//-- Echo --------------------------
  IF(uComm.bEchoTX) {
    echoTx ("uQue.uLastItem.cAlias", "uQue.uLastItem.cData")
  }

//-- Delay -------------------------
  lTlTimes[1] = MAX_VALUE(50, uQue.uLastItem.lDelay)
  lTlTimes[2] = 10
  TIMELINE_CREATE(TL_QUE, lTlTimes, 2, TIMELINE_RELATIVE, TIMELINE_ONCE)
  ON[vdvAPI,QUE_EDGE]

//-- Counter -----------------------
#IF_DEFINED TL_COUNTER_PWR
  SWITCH(uQue.uLastItem.cAlias)
  {
    CASE 'PWR-ON'  :
    CASE 'PWR-OFF' : {
      STACK_VAR INTEGER nSeconds

      nSeconds = TYPE_CAST(lTlTimes[1] / 1000)
      uCounterPwr.nCount = nSeconds
      uCounterPwr.nStart = nSeconds
      IF(uQue.uLastItem.cAlias = 'PWR-ON')  uCounterPwr.cContext = 'WARMING'
      ELSE                                  uCounterPwr.cContext = 'COOLING'

      [vdvAPI,WARMING_FB] = (uQue.uLastItem.cAlias = 'PWR-ON')
      [vdvAPI,COOLING_FB] = (uQue.uLastItem.cAlias = 'PWR-OFF')

      lTlTimes[1] = 1000
      TIMELINE_CREATE(TL_COUNTER_PWR, lTlTimes, 1, TIMELINE_RELATIVE, TIMELINE_REPEAT)

      SEND_COMMAND vdvAPI,"uCounterPwr.cContext,'-',ITOA(uCounterPwr.nCount),',',ITOA(uCounterPwr.nStart)"
    }
  }
#END_IF

  RETURN (TRUE)
}

//----------------------------------------------------------
// Does que have any items?
//----------------------------------------------------------
DEFINE_FUNCTION CHAR queHasItems ()
{
	IF(TIMELINE_ACTIVE(TL_QUE))
		RETURN (TRUE)

	RETURN (uQue.nLast && (uQue.nCurrent <> uQue.nLast))
}

//----------------------------------------------------------
// Que timeout (expired or advanced).
//----------------------------------------------------------
DEFINE_FUNCTION queExpired ()
{
//-- Que -----------
  OFF[vdvAPI,QUE_EDGE]

//-- Misc FB -------
#IF_DEFINED WARMING_FB  OFF[vdvAPI,WARMING_FB]  #END_IF
#IF_DEFINED COOLING_FB  OFF[vdvAPI,COOLING_FB]  #END_IF
}

//----------------------------------------------------------
// Advance to next.
//----------------------------------------------------------
DEFINE_FUNCTION queAdvance ()
{
  IF(TIMELINE_ACTIVE(TL_QUE)) {
    STACK_VAR LONG lTlTimes[2]

    lTlTimes[1] = 10
    lTlTimes[2] = 10
    TIMELINE_RELOAD(TL_QUE, lTlTimes, 2)

    queExpired ()
  }

  queCheck ()
}

//----------------------------------------------------------
// Find this alias in the que.
//----------------------------------------------------------
DEFINE_FUNCTION INTEGER queFind (CHAR cAlias[])
STACK_VAR
  INTEGER nLoop
{
//-- Check navigation --------------
	IF(!uQue.nCurrent)
		RETURN (0)

	IF(uQue.nCurrent = uQue.nLast)
		RETURN (0)

//-- Iterate and find --------------
	IF(uQue.nCurrent > uQue.nLast)    // Que is a rolled over
	{
		FOR(nLoop=uQue.nCurrent; nLoop<=MAX_LENGTH_ARRAY(uQue.uItem); nLoop++)
		{
			IF(FIND_STRING(uQue.uItem[nLoop].cAlias,"cAlias",1))
				RETURN (nLoop)
		}
		FOR(nLoop=1; nLoop<=uQue.nLast; nLoop++)
		{
			IF(FIND_STRING(uQue.uItem[nLoop].cAlias,"cAlias",1))
				RETURN (nLoop)
		}
	}
	ELSE                              // From nCurrent to nLast
	{
		FOR(nLoop=uQue.nCurrent; nLoop<=uQue.nLast; nLoop++)
		{
			IF(FIND_STRING(uQue.uItem[nLoop].cAlias,"cAlias",1))
				RETURN (nLoop)
		}
	}

	RETURN (0)
}

//----------------------------------------------------------
// Clear the que of any pending items.
//----------------------------------------------------------
DEFINE_FUNCTION queClear ()
STACK_VAR
	INTEGER   nLoop
	_uQueItem uItemBlank
{
//-- Reset navigation --------------
	uQue.nLast = 0
	uQue.nCurrent = 0

//-- Reset data --------------------
	FOR(nLoop=1; nLoop<=MAX_LENGTH_ARRAY(uQue.uItem); nLoop++) {
		IF(nLoop <> uQue.nCurrent)
			uQue.uItem[nLoop] = uItemBlank
	}
}

//----------------------------------------------------------
// Reset the que and cancel timeout.
//----------------------------------------------------------
DEFINE_FUNCTION queReset ()
STACK_VAR
	_uQueItem uItemBlank
	_uCounter uCounterBlank
{
  queClear ()
  queExpired ()

  IF(TIMELINE_ACTIVE(TL_QUE))
    TIMELINE_KILL(TL_QUE)

  uQue.uLastItem = uItemBlank
  uCounterPwr    = uCounterBlank
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Heartbeat helpers ---------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Start heartbeat.
//----------------------------------------------------------
DEFINE_FUNCTION heartbeatStart ()
{
#IF_DEFINED TL_HEARTBEAT
  IF(!TIMELINE_ACTIVE(TL_HEARTBEAT)) {
    STACK_VAR LONG lTlTimes[1]

    lTlTimes[1] = HEARTBEAT_DELAY
    TIMELINE_CREATE(TL_HEARTBEAT, lTlTimes, 1, TIMELINE_RELATIVE, TIMELINE_REPEAT)
  }
#END_IF
}

//----------------------------------------------------------
// Stop heartbeat.
//----------------------------------------------------------
DEFINE_FUNCTION heartbeatStop ()
{
#IF_DEFINED TL_HEARTBEAT
  IF(TIMELINE_ACTIVE(TL_HEARTBEAT)) {
    TIMELINE_KILL(TL_HEARTBEAT)
  }
#END_IF
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Polling helpers -----------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Start polling.
//----------------------------------------------------------
DEFINE_FUNCTION pollStart ()
{
  IF(uProp.nPollDelay = 0)
    RETURN;

#IF_DEFINED TL_POLL
  uComm.nPollStep    = 1
  uComm.nPollCounter = 0

  IF(!TIMELINE_ACTIVE(TL_POLL)) {
    STACK_VAR LONG lTlTimes[1]

    lTlTimes[1] = uProp.nPollDelay * 1000
    TIMELINE_CREATE(TL_POLL, lTlTimes, 1, TIMELINE_RELATIVE, TIMELINE_REPEAT)
  }
#END_IF
}

//----------------------------------------------------------
// Stop polling.
//----------------------------------------------------------
DEFINE_FUNCTION pollStop ()
{
#IF_DEFINED TL_POLL
  IF(TIMELINE_ACTIVE(TL_POLL)) {
    TIMELINE_KILL(TL_POLL)
  }
#END_IF
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- String helpers ------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------
// A string replace utility.
// Credit to: https://github.com/avt-its-simple/amx-util-library/blob/master/string.axi
//-----------------------------------------------------------
DEFINE_FUNCTION INTEGER stringReplace (CHAR strSearch[], CHAR strToReplace[], CHAR strReplacement[])
STACK_VAR
  INTEGER indexReplace
{
	IF((strSearch == '') || (strToReplace == ''))
		RETURN (FALSE)

	indexReplace = FIND_STRING(strSearch,strToReplace,1)

	IF(!indexReplace)
		RETURN (FALSE)

	strSearch = "MID_STRING(strSearch,1,(indexReplace-1)),
	             strReplacement,
	             MID_STRING(strSearch,(indexReplace+LENGTH_STRING(strToReplace)),(LENGTH_STRING(strSearch)-(indexReplace+LENGTH_STRING(strToReplace))+1))"

	RETURN (TRUE)
}

//-----------------------------------------------------------
// Parses 'Value to return<Delim>' and returns everything
// that is before the '<Delim>'.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR[5000] stringLeft (CHAR strText[],CHAR strSearch[])
STACK_VAR
  INTEGER nFirst
  INTEGER nLast
  INTEGER nCount
{
//-- Look for a quick bail-out -----
  nFirst = 1
  nLast  = FIND_STRING(strText,"strSearch",1)

  IF((nFirst=0) || (nLast=0))
    RETURN ('')

//-- Set the count (of value) ------
  nFirst = 1
  nCount = nLast - 1

  RETURN (MID_STRING(strText,nFirst,nCount))
}

//-----------------------------------------------------------
// Parses <Start>Value to return<End> and returns the
// value in-between.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR[5000] stringMid (CHAR strText[], CHAR strStart[], CHAR strEnd[])
STACK_VAR
  INTEGER nFirst
  INTEGER nLast
  INTEGER nCount
{
//-- Look for a quick bail-out -----
  nFirst = FIND_STRING(strText,"strStart",1)
  IF(nFirst && (LENGTH_STRING(strText) >= nFirst+1))
    nLast  = FIND_STRING(strText,"strEnd",nFirst+LENGTH_STRING(strStart))

  IF((nFirst=0) || (nLast=0))
    RETURN ('')

//-- Set the count (of value) ------
  nFirst = nFirst + LENGTH_STRING(strStart)
  nCount = nLast - nFirst

  RETURN (MID_STRING(strText,nFirst,nCount))
}

//-----------------------------------------------------------
// Parses 'Value=Value to return' and returns everything
// that remains after 'Value='.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR[5000] stringRight (CHAR strText[], CHAR strSearch[])
STACK_VAR
  INTEGER nLoop
  INTEGER nFirst
  INTEGER nLast
  INTEGER nCount
{
//-- Look for a quick bail-out -----
  nFirst = FIND_STRING(strText,"strSearch",1)
  nLast  = LENGTH_STRING(strText)

  IF((nFirst=0) || (nLast=0))
    RETURN ('')

//-- Search from the right ---------
  nLoop = 1
  WHILE(nLoop <> 0)
  {
    nFirst = FIND_STRING(strText,"strSearch",nLoop)

    IF(FIND_STRING(strText,"strSearch",nFirst + LENGTH_STRING(strSearch)))
      nLoop = nFirst + LENGTH_STRING(strSearch)
    ELSE
      nLoop = 0
  }

//-- Set the count (of value) ------
  nFirst = nFirst + LENGTH_STRING(strSearch)
  nCount = nLast - nFirst + 1

  RETURN (MID_STRING (strText,nFirst,nCount))
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Level helpers -------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------
// Set uLvl for snValue.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR lvlSet (_uLvl uLvl, SINTEGER snValue)
{
  IF(snValueInRange (snValue, uLvl.snMin, uLvl.snMax)) {
    uLvl.snValue = snValue
    uLvl.nBG     = snValueToBG (snValue, uLvl.snMin, uLvl.snMax)
    RETURN (TRUE)
  }

  RETURN (FALSE)
}

//-----------------------------------------------------------
// Inc/Dec uLvl within range.
//-----------------------------------------------------------
DEFINE_FUNCTION lvlStep (_uLvl uLvl, SINTEGER snStep)
{
  uLvl.snValue = uLvl.snValue + snStep

  IF(snStep > 0)        // Raising
  {
    IF(uLvl.snValue > uLvl.snMax)
      uLvl.snValue = uLvl.snMax
  }
  ELSE IF(snStep < 0)   // Lowering
  {
    IF((uLvl.snValue < uLvl.snMin) || (uLvl.snValue > uLvl.snMax))
      uLvl.snValue = uLvl.snMin
  }

  uLvl.nBG = snValueToBG (uLvl.snValue, uLvl.snMin, uLvl.snMax)
}

//-----------------------------------------------------------
// Create a bargraph value from snValue.
//-----------------------------------------------------------
DEFINE_FUNCTION INTEGER snValueToBG (SINTEGER snValue, SINTEGER snMin, SINTEGER snMax)
STACK_VAR
  INTEGER nBG
{
//-- Let's bounds check first ------
  IF(snValue <= snMin) {
    RETURN (0)
  }

  IF(snValue >= snMax) {
    RETURN (255)
  }

//-- Avoid divide by zero ----------
  IF((snMax - snMin) = 0) {
    RETURN (0)
  }

//-- nBG is 0-255 ------------------
  nBG = TYPE_CAST(snValue - snMin)
  nBG = (nBG * 255) / TYPE_CAST((snMax - snMin))

  RETURN (nBG)
}

//-----------------------------------------------------------
// Is snValue within range?
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR snValueInRange (SINTEGER snValue, SINTEGER snMin, SINTEGER snMax)
{
  RETURN ((snValue >= snMin) && (snValue <= snMax))
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- SNAPi helpers ------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------
// Return boolean for string.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR snapiGetBoolean (CHAR cValue[])
{
	IF(cValue = "1")  RETURN (TRUE)
	IF(cValue = "0")  RETURN (FALSE)

	IF(cValue = '1')  RETURN (TRUE)
	IF(cValue = '0')  RETURN (FALSE)

	SWITCH(UPPER_STRING(cValue))
	{
		CASE 'ON'   :
		CASE 'TRUE' : RETURN (TRUE)
		DEFAULT     : RETURN (FALSE)
	}
}

//-----------------------------------------------------------
// Return string for boolean.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR[5] snapiGetBooleanString (CHAR cValue[])
{
	IF(snapiGetBoolean (cValue))
		RETURN ('TRUE')

	RETURN ('FALSE')
}

//-----------------------------------------------------------
// Return string for channel.
//-----------------------------------------------------------
DEFINE_FUNCTION CHAR[5] snapiGetBooleanChannel (CHAR cValue)
{
  IF(cValue)  RETURN ('TRUE')
  ELSE        RETURN ('FALSE')
}


//!------------------------------------------------------------------------------------------------------------------
//---------------------------------- Echo helpers -------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Logging helper.
//----------------------------------------------------------
DEFINE_FUNCTION log (LONG lLvl, CHAR cContext[], CHAR cMsg[])
{
  SWITCH(lLvl)
  {
    CASE AMX_ERROR   : AMX_LOG (lLvl, logFormat ('ERROR', cContext, cMsg))
    CASE AMX_WARNING : AMX_LOG (lLvl, logFormat ('WARN' , cContext, cMsg))
    CASE AMX_INFO    : AMX_LOG (lLvl, logFormat ('INFO' , cContext, cMsg))
    CASE AMX_DEBUG   : AMX_LOG (lLvl, logFormat ('DEBUG', cContext, cMsg))
  }
}

//----------------------------------------------------------
// Standard log format: | MDL_NAME | ERROR | DATE | TIME | CONTEXT | MSG
//----------------------------------------------------------
DEFINE_FUNCTION CHAR[500] logFormat (CHAR cLvl[], CHAR cContext[], CHAR cMsg[])
{
  RETURN(" '| ',cMDL_NAME,
          ' | ',LEFT_STRING("cLvl,'     '",5),
          ' | ',LDATE,' | ',TIME,
          ' | ',cContext,
          ' | ',cMsg")
}

//----------------------------------------------------------
// Echo last Tx.
//----------------------------------------------------------
DEFINE_FUNCTION echoTx (CHAR cAlias[], CHAR cData[])
{
  SEND_STRING 0,"logFormat ('Sent', 'CMD_ALIAS' , "cAlias")"
  IF(bAPI_IS_HEX)    echoHex   (cData)
  ELSE               echoAscii (cData)
}

//----------------------------------------------------------
// Echo last Rx.
//----------------------------------------------------------
DEFINE_FUNCTION echoRx (CHAR cAlias[], CHAR cReply[])
{
  SEND_STRING 0,"logFormat ('Rcvd', 'CMD_ALIAS' , "cAlias")"
  IF(bAPI_IS_HEX)    echoHex   (cReply)
  ELSE               echoAscii (cReply)
}

//----------------------------------------------------------
// Terminal echo as hex.
//----------------------------------------------------------
DEFINE_FUNCTION echoHex (CHAR cData[])
STACK_VAR
  INTEGER nLoop
  INTEGER nCount
  CHAR    strTXT1[100]
  CHAR    strTXT2[100]
  CHAR    strTXT3[100]
{
  strTXT1 = ""
  strTXT2 = ""
  strTXT3 = ""
  nLoop   = 1
  nCount  = 1
  WHILE (nLoop <= LENGTH_STRING(cData))
  {
    strTXT1 = "strTXT1,RIGHT_STRING("'   ',ITOA(cData[nLoop])",3),'/'"          // DECIMAL
    strTXT2 = "strTXT2,'$',RIGHT_STRING("'00',ITOHEX(cData[nLoop])",2),'/'"     // HEX
    IF ((cData[nLoop] >= 33) && (cData[nLoop] <= 126))
      strTXT3 = "strTXT3,'  ',cData[nLoop],' '"
    ELSE
      strTXT3 = "strTXT3,'    '"

    nLoop = nLoop + 1

    IF(nCount = 10)
    {
      nCount = 1
      SEND_STRING 0,"'  ',strTXT1"
      SEND_STRING 0,"'  ',strTXT2"
      SEND_STRING 0,"'  ',strTXT3"
      strTXT1 = ""
      strTXT2 = ""
      strTXT3 = ""
    }
    ELSE
      nCount = nCount + 1
  }

  SEND_STRING 0,"'  ',strTXT1"
  SEND_STRING 0,"'  ',strTXT2"
  SEND_STRING 0,"'  ',strTXT3"
}

//----------------------------------------------------------
// Terminal echo as ascii.
//----------------------------------------------------------
DEFINE_FUNCTION echoAscii (CHAR cData[])
STACK_VAR
  INTEGER nLoop
{
  FOR(nLoop=1; nLoop<=LENGTH_STRING(cData); nLoop=nLoop+80)
  {
    IF(LENGTH_STRING(cData) > (nLoop-1+80))
      SEND_STRING 0,"'  ',MID_STRING(cData,nLoop,80)"
    ELSE
      SEND_STRING 0,"'  ',MID_STRING(cData,nLoop,LENGTH_STRING(cData)-nLoop+1)"
  }
}


//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Misc helpers -------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------


//==============================================================================
// Start
//==============================================================================
DEFINE_START

//-- Print version -----------------------------------------
SEND_STRING 0,"'  Implementing rcMDL (',__LDATE__,'@',__TIME__,') v0.0.0'"


//==============================================================================
// Events
//==============================================================================
DEFINE_EVENT

//!-------------------------------------------------------------------------------------------------------------------
//---------------------------------- Debug Interfaces ----------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------
// Device echo
//----------------------------------------------------------
CHANNEL_EVENT[vdvAPI,DEBUG_TX]
{
  ON :
  {
    uComm.bEchoTX = TRUE
    SEND_STRING 0,"logFormat ('Tx', 'ON' , 'DEBUG_TX turned on.')"
  }
  OFF :
  {
    uComm.bEchoTX = FALSE
    SEND_STRING 0,"logFormat ('Tx', 'OFF', 'DEBUG_TX turned off.')"
  }
}

CHANNEL_EVENT[vdvAPI,DEBUG_RX]
{
  ON :
  {
    uComm.bEchoRX = TRUE
    SEND_STRING 0,"logFormat ('Rx', 'ON' , 'DEBUG_RX turned on.')"
  }
  OFF :
  {
    uComm.bEchoRX = FALSE
    SEND_STRING 0,"logFormat ('Rx', 'OFF', 'DEBUG_RX turned off.')"
  }
}


//==============================================================================
// End
//==============================================================================
#END_IF

