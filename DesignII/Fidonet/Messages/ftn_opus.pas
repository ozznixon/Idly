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


class function TIdlyOpusMsgEngine.ReadMessage(const FilePath: string; out Msg: TFTNMessageData): Boolean;
var
  FS: TFileStream;
  RawByte: Byte;
begin
  Result := False;
  if not FileExists(FilePath) then Exit;

  FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size < SizeOf(TMSGHeader) then Exit;
    
    // 1. Pull fixed 190-byte structural header
    FS.ReadBuffer(Msg.Header, SizeOf(TMSGHeader));

    // 2. Synthesize clean 4D addressing properties using structural attributes
    Msg.OrigAddr.Zone  := Msg.Header.OrigZone;
    Msg.OrigAddr.Net   := Msg.Header.OrigNet;
    Msg.OrigAddr.Node  := Msg.Header.OrigNode;
    Msg.OrigAddr.Point := Msg.Header.OrigPoint;

    Msg.DestAddr.Zone  := Msg.Header.DestZone;
    Msg.DestAddr.Net   := Msg.Header.DestNet;
    Msg.DestAddr.Node  := Msg.Header.DestNode;
    Msg.DestAddr.Point := Msg.Header.DestPoint;

    // 3. Extract the message body trailing text stream
    SetLength(Msg.BodyText, FS.Size - FS.Position);
    if Length(Msg.BodyText) > 0 then
    begin
      FS.ReadBuffer(Pointer(Msg.BodyText)^, Length(Msg.BodyText));
      
      // Clean up final null string terminator if it was explicitly written to disk
      if (Length(Msg.BodyText) > 0) and (Msg.BodyText[Length(Msg.BodyText)] = #0) then
        SetLength(Msg.BodyText, Length(Msg.BodyText) - 1);
    end;

    Result := True;
  finally
    FS.Free;
  end;
end;

class function TIdlyOpusMsgEngine.WriteMessage(const FilePath: string; var Msg: TFTNMessageData): Boolean;
var
  FS: TFileStream;
  NullTerminator: Byte;
begin
  Result := False;
  
  // Sync the raw address elements back into header properties before execution
  Msg.Header.OrigZone := Msg.OrigAddr.Zone;
  Msg.Header.OrigNet  := Msg.OrigAddr.Net;
  Msg.Header.OrigNode := Msg.OrigAddr.Node;
  Msg.Header.OrigPoint := Msg.OrigAddr.Point;

  Msg.Header.DestZone := Msg.DestAddr.Zone;
  Msg.Header.DestNet  := Msg.DestAddr.Net;
  Msg.Header.DestNode := Msg.DestAddr.Node;
  Msg.Header.DestPoint := Msg.DestAddr.Point;

  FS := TFileStream.Create(FilePath, fmCreate);
  try
    // 1. Commit structural fixed configuration values
    FS.WriteBuffer(Msg.Header, SizeOf(TMSGHeader));

    // 2. Stream out dynamic text payload elements
    if Length(Msg.BodyText) > 0 then
      FS.WriteBuffer(Pointer(Msg.BodyText)^, Length(Msg.BodyText));

    // 3. Append formal termination indicator byte 
    NullTerminator := 0;
    FS.WriteByte(NullTerminator);

    Result := True;
  finally
    FS.Free;
  end;
end;

end.
