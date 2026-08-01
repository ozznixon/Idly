(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Compiler.pas                                           *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit Compiler;

{$mode objfpc}{$H+}
{$packrecords 1} // Ensure perfect binary byte alignment on disk

interface

uses
  SysUtils, Classes;

type
  TNodelistFormat = (nlv7, nlv6, nlQbbs);

  // Unified 4D Node Routing Block written directly to binary files
  TNodeRecord = packed record
    Zone: Word;
    Net: Word;
    Node: Word;
    Point: Word;
    Flags: LongWord;                 // Bitmapped routing capabilities (CM, IBN, BINKP)
    BaudRate: Word;
    Name: array[0..29] of Char;      // Clean system name
    Location: array[0..29] of Char;  // City/State
    Phone: array[0..19] of Char;     // Protocol string or phone
  end;

  TIdlyNodelistCompiler = class
  private
    FCurrentZone: Word;
    FCurrentNet: Word;
    FCurrentNode: Word;
    FOutStream: TFileStream;
    procedure ParseV7Line(const Line: string);
    procedure ParseV6Line(const Line: string);
    procedure ParseQbbsLine(const Line: string);
    procedure AppendRecord(const Rec: TNodeRecord);
  public
    constructor Create(const TargetBinaryFile: string);
    destructor Destroy; override;
    procedure Compile(const SourceTextFile: string; Format: TNodelistFormat);
  end;

implementation
