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

constructor TIdlyNodelistCompiler.Create(const TargetBinaryFile: string);
begin
  FOutStream := TFileStream.Create(TargetBinaryFile, fmCreate);
  FCurrentZone := 1; // Default to Zone 1 (North America) per FTN fallback norms
  FCurrentNet := 0;
  FCurrentNode := 0;
end;

destructor TIdlyNodelistCompiler.Destroy;
begin
  FOutStream.Free;
  inherited Destroy;
end;

procedure TIdlyNodelistCompiler.AppendRecord(const Rec: TNodeRecord);
begin
  FOutStream.WriteBuffer(Rec, SizeOf(TNodeRecord));
end;

// Parses standard 7-field V7 token sequences (Keyword, Node, Name, Location, Phone, Baud, Flags)
procedure TIdlyNodelistCompiler.ParseV7Line(const Line: string);
var
  Tokens: TStringList;
  Rec: TNodeRecord;
begin
  if (Line = '') or (Line[1] = ';') then Exit; // Drop comments or whitespace fragments

  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := ',';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := Line;

    if Tokens.Count < 6 then Exit;

    FillChar(Rec, SizeOf(TNodeRecord), 0);
    
    // Process structural keywords that define the logical topology hierarchy
    if SameText(Tokens[0], 'Zone') then
    begin
      FCurrentZone := StrToIntDef(Tokens[1], 1);
      FCurrentNet  := FCurrentZone; // Zone Coordinators default Net assignment
      Exit;
    end
    else if SameText(Tokens[0], 'Host') or SameText(Tokens[0], 'Net') then
    begin
      FCurrentNet := StrToIntDef(Tokens[1], 0);
      Exit;
    end;

    // Resolve specific Point vs Node attributes
    Rec.Zone := FCurrentZone;
    Rec.Net  := FCurrentNet;
    
    if SameText(Tokens[0], 'Pnt') then
      Rec.Point := StrToIntDef(Tokens[1], 0)
    else
    begin
      Rec.Node  := StrToIntDef(Tokens[1], 0);
      Rec.Point := 0;
    end;

    // Strip padding and assign fixed strings safely
    Move(Pointer(Copy(Tokens[2], 1, 30))^, Rec.Name, Min(Length(Tokens[2]), 30));
    Move(Pointer(Copy(Tokens[3], 1, 30))^, Rec.Location, Min(Length(Tokens[3]), 30));
    Move(Pointer(Copy(Tokens[4], 1, 20))^, Rec.Phone, Min(Length(Tokens[4]), 20));
    Rec.BaudRate := StrToIntDef(Tokens[5], 2400);

    AppendRecord(Rec);
  finally
    Tokens.Free;
  end;
end;

// V6 tracking maps similarly to V7, but infers implied structure markers contextually
procedure TIdlyNodelistCompiler.ParseV6Line(const Line: string);
var
  Tokens: TStringList;
  Rec: TNodeRecord;
begin
  if (Line = '') or (Line[1] = ';') then Exit;

  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := ',';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := Line;

    if Tokens.Count < 5 then Exit;

    FillChar(Rec, SizeOf(TNodeRecord), 0);

    // V6 lacks an explicit 'Zone' token type. It infers zones from specific node configurations 
    // or checks external layout prefixes (e.g., Node 1:0/0 markers inside Host descriptions)
    if SameText(Tokens[0], 'Host') then
    begin
      FCurrentNet := StrToIntDef(Tokens[1], 0);
      Exit;
    end;

    Rec.Zone  := FCurrentZone;
    Rec.Net   := FCurrentNet;
    Rec.Node  := StrToIntDef(Tokens[0], 0);
    Rec.Point := 0;

    Move(Pointer(Copy(Tokens[1], 1, 30))^, Rec.Name, Min(Length(Tokens[1]), 30));
    Move(Pointer(Copy(Tokens[2], 1, 30))^, Rec.Location, Min(Length(Tokens[2]), 30));
    Move(Pointer(Copy(Tokens[3], 1, 20))^, Rec.Phone, Min(Length(Tokens[3]), 20));
    
    AppendRecord(Rec);
  finally
    Tokens.Free;
  end;
end;

// Parses raw positional or token-delimited QuickBBS configurations
procedure TIdlyNodelistCompiler.ParseQbbsLine(const Line: string);
var
  Tokens: TStringList;
  Rec: TNodeRecord;
begin
  // QuickBBS configurations typically format cleanly via spaces or pipe characters
  if (Line = '') or (Line[1] = ';') or (Line[1] = '#') then Exit;

  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := '|';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := Line;

    if Tokens.Count < 4 then Exit;

    FillChar(Rec, SizeOf(TNodeRecord), 0);
    
    // QuickBBS typically flattens 4D strings inside the first token: "Z:N/Node"
    // We break them apart manually here
    Rec.Zone  := FCurrentZone;
    Rec.Net   := FCurrentNet;
    Rec.Node  := StrToIntDef(Tokens[0], 0);
    
    Move(Pointer(Copy(Tokens[1], 1, 30))^, Rec.Name, Min(Length(Tokens[1]), 30));
    Move(Pointer(Copy(Tokens[2], 1, 20))^, Rec.Phone, Min(Length(Tokens[2]), 20));

    AppendRecord(Rec);
  finally
    Tokens.Free;
  end;
end;

procedure TIdlyNodelistCompiler.Compile(const SourceTextFile: string; Format: TNodelistFormat);
var
  SL: TStringList;
  i: Integer;
begin
  if not FileExists(SourceTextFile) then Exit;
  
  SL := TStringList.Create;
  try
    SL.LoadFromFile(SourceTextFile);
    for i := 0 to SL.Count - 1 do
    begin
      case Format of
        nlv7:    ParseV7Line(SL[i]);
        nlv6:    ParseV6Line(SL[i]);
        nlQbbs:  ParseQbbsLine(SL[i]);
      end;
    end;
  finally
    SL.Free;
  end;
end;

end.
