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
