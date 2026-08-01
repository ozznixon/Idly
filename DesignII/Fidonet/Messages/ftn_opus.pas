(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: FTN.Opus.pas                                           *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit ftn_opus;

{$mode objfpc}{$H+}
{$packrecords 1} // Strict 1-byte field packing alignment for binary file compatibility

interface

uses
  SysUtils, Classes;

const
  // FTS-0001 / FSC-0048 Message Attribute Bitmasks
  MSG_ATTR_PRIVATE    = $0001;
  MSG_ATTR_CRASH      = $0002;
  MSG_ATTR_RECD       = $0004;
  MSG_ATTR_SENT       = $0008;
  MSG_ATTR_FILEATTACH = $0010;
  MSG_ATTR_INTRANSIT  = $0020;
  MSG_ATTR_ORPHAN     = $0040;
  MSG_ATTR_KILL_SENT  = $0080;
  MSG_ATTR_LOCAL      = $0100;
  MSG_ATTR_HOLD       = $0200;
  MSG_ATTR_FREQ       = $0800; // File Request
  MSG_ATTR_RRQ        = $1000; // Return Receipt Request

type
  // Traditional 190-byte FTS-0001 Fixed Binary Header Block
  TMSGHeader = packed record
    FromUser: array[0..35] of Char; // Null-terminated ASCII
    ToUser: array[0..35] of Char;
    Subject: array[0..71] of Char;
    DateTime: array[0..19] of Char; // Format: "DD Mmm YY  HH:MM:SS"
    TimesRead: Word;
    DestNode: Word;                 // Legacy 2D Addressing
    OrigNode: Word;
    Cost: Word;
    OrigNet: Word;
    DestNet: Word;
    
    // FSC-0048 Type 2+ Zone & Point Extension Fields (Overlays legacy filler spacing)
    DestZone: Word;                 
    OrigZone: Word;                 
    OrigPoint: Word;                
    DestPoint: Word;                
    
    ReplyTo: Word;                  // Thread linking values
    Attribute: Word;                // Dynamic bitmask configurations
    NextReply: Word;
  end;

  // Modern 4D Address Record Layout
  TFTNAddress = record
    Zone, Net, Node, Point: Word;
  end;

  TFTNMessageData = record
    Header: TMSGHeader;
    OrigAddr: TFTNAddress;
    DestAddr: TFTNAddress;
    BodyText: string;
  end;

  TIdlyOpusMsgEngine = class
  public
    class function ReadMessage(const FilePath: string; out Msg: TFTNMessageData): Boolean;
    class function WriteMessage(const FilePath: string; var Msg: TFTNMessageData): Boolean;
  end;

implementation
