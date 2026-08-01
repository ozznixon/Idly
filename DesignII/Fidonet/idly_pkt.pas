(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.PKT.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_pkt;

{$mode objfpc}{$H+}
{$packrecords 1} // Enforce strict 1-byte structural alignment for binary streams

interface

uses
  SysUtils, Classes;

type
  // FTS-0001 Type-2+ PKT Header Type Definition
  TPKTHeader = packed record
    OrigNode: Word;
    DestNode: Word;
    Year: Word;       // 4-digit format
    Month: Word;      // 0-11 format
    Day: Word;        // 1-31 format
    Hour: Word;       // 0-23 format
    Minute: Word;     // 0-59 format
    Second: Word;     // 0-59 format
    Baud: Word;       // Legacy compatibility spacing (typically 0)
    PktType: Word;    // Always 2 for standard Type 2 / 2+ files
    OrigNet: Word;
    DestNet: Word;
    ProdCodeByte: Byte;
    RevMajor: Byte;
    Password: array[0..7] of Char; // Null padded password tracking
    OrigZone: Word;   // FTS-5005 / FSC-0048 Extensions
    DestZone: Word;
    OrigPoint: Word;
    DestPoint: Word;
    DataLong: LongInt; // Reserved / Cap-data tracking
  end;

  // Header prefix for individual messages inside a PKT container
  TPKTMessageHeader = packed record
    TypePacked: Word; // Always 2
    OrigNode: Word;
    DestNode: Word;
    OrigNet: Word;
    DestNet: Word;
    Attribute: Word;  // Private, Crash, Hold, FileAttach flags
    Cost: Word;
  end;

  // High-level abstraction for mapping message items cleanly
  TFTNMessage = record
    OrigZone, OrigNet, OrigNode, OrigPoint: Word;
    DestZone, DestNet, DestNode, DestPoint: Word;
    DateTimeStr: string[20]; // Format: "DD Mmm YY  HH:MM:SS"
    FromUser: string;
    ToUser: string;
    Subject: string;
    Text: string;
  end;

  TIdlyPKTEngine = class
  public
    class procedure ReadPacket(const PktFileName: string);
    class procedure CreatePacket(const OutPktPath: string; const Header: TPKTHeader; const Msg: TFTNMessage);
  end;

implementation


// Utility helper to cleanly consume null-terminated strings from raw streams
function ReadNullStr(Stream: TStream): string;
var
  B: Byte;
begin
  Result := '';
  while Stream.Position < Stream.Size do
  begin
    B := Stream.ReadByte;
    if B = 0 then Break;
    Result := Result + Chr(B);
  end;
end;

// Utility helper to write string fields with their required null terminator
procedure WriteNullStr(Stream: TStream; const S: string);
begin
  if Length(S) > 0 then
    Stream.Write(Pointer(S)^, Length(S));
  Stream.WriteByte(0);
end;

class procedure TIdlyPKTEngine.ReadPacket(const PktFileName: string);
var
  FS: TFileStream;
  PktHdr: TPKTHeader;
  MsgHdr: TPKTMessageHeader;
  Msg: TFTNMessage;
  Terminator: Word;
begin
  if not FileExists(PktFileName) then Exit;
  FS := TFileStream.Create(PktFileName, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size < SizeOf(TPKTHeader) then Exit;
    FS.ReadBuffer(PktHdr, SizeOf(TPKTHeader));

    // Iterate through individual embedded message blocks
    while FS.Position < (FS.Size - 2) do
    begin
      FS.ReadBuffer(MsgHdr, SizeOf(TPKTMessageHeader));
      
      // Assign known zone tracking context from global packet topology headers
      Msg.OrigZone := PktHdr.OrigZone;
      Msg.DestZone := PktHdr.DestZone;
      Msg.OrigNet  := MsgHdr.OrigNet;
      Msg.OrigNode := MsgHdr.OrigNode;
      Msg.DestNet  := MsgHdr.DestNet;
      Msg.DestNode := MsgHdr.DestNode;
      Msg.OrigPoint := PktHdr.OrigPoint;
      Msg.DestPoint := PktHdr.DestPoint;

      // Extract fixed-length FTN timestamp block string
      FS.ReadBuffer(Msg.DateTimeStr[1], 20);
      Msg.DateTimeStr[0] := #20;

      // Extract variables strings sequentially
      Msg.ToUser   := ReadNullStr(FS);
      Msg.FromUser := ReadNullStr(FS);
      Msg.Subject  := ReadNullStr(FS);
      Msg.Text     := ReadNullStr(FS);

      // --- INBOUND HOOK ---
      // Your mail tosser parses or logs messages into disk destinations here:
      Writeln('From:    ', Msg.FromUser, ' (', Msg.OrigZone, ':', Msg.OrigNet, '/', Msg.OrigNode, ')');
      Writeln('To:      ', Msg.ToUser);
      Writeln('Subject: ', Msg.Subject);
      Writeln('---');
    end;

    // Verify trailing packet exit bounds check marker sequence
    if FS.Position <= FS.Size - 2 then
    begin
      FS.ReadBuffer(Terminator, 2);
      if Terminator <> 0 then Writeln('Warning: Bad packet termination sequence.');
    end;

  finally
    FS.Free;
  end;
end;

class procedure TIdlyPKTEngine.CreatePacket(const OutPktPath: string; const Header: TPKTHeader; const Msg: TFTNMessage);
var
  FS: TFileStream;
  MsgHdr: TPKTMessageHeader;
  Terminator: Word;
begin
  // Initialize file context wrapper stream patterns cleanly
  if FileExists(OutPktPath) then
    FS := TFileStream.Create(OutPktPath, fmOpenReadWrite)
  else
  begin
    FS := TFileStream.Create(OutPktPath, fmCreate);
    FS.WriteBuffer(Header, SizeOf(TPKTHeader));
  end;

  try
    // Advance internal file position past prior headers if appending entries
    if FS.Size > SizeOf(TPKTHeader) then
      FS.Position := FS.Size - 2
    else
      FS.Position := FS.Size;

    // Fill message level metadata structural blocks cleanly
    FillChar(MsgHdr, SizeOf(TPKTMessageHeader), 0);
    MsgHdr.TypePacked := 2;
    MsgHdr.OrigNode   := Msg.OrigNode;
    MsgHdr.DestNode   := Msg.DestNode;
    MsgHdr.OrigNet    := Msg.OrigNet;
    MsgHdr.DestNet    := Msg.DestNet;
    MsgHdr.Attribute  := 1; // Default to Private Mail context rules

    FS.WriteBuffer(MsgHdr, SizeOf(TPKTMessageHeader));
    FS.WriteBuffer(Msg.DateTimeStr[1], 20);

    // Stream variable data components safely matching out boundaries
    WriteNullStr(FS, Msg.ToUser);
    WriteNullStr(FS, Msg.FromUser);
    WriteNullStr(FS, Msg.Subject);
    WriteNullStr(FS, Msg.Text);

    // Append the mandatory final 2-byte packet termination marker string sequence
    Terminator := 0;
    FS.WriteBuffer(Terminator, 2);

  finally
    FS.Free;
  end;
end;

end.
