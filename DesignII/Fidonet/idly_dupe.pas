(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Dupe.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_dupe;

{$mode objfpc}{$H+}
{$packrecords 1}

interface

uses
  SysUtils, Classes;

type
  TDupeRecord = packed record
    Hash: LongWord;
    Timestamp: Int64;
  end;

  TIdlyDupeChecker = class
  private
    FFileName: string;
    FList: array of TDupeRecord;
    FCount: Integer;
    function CalculateCRC32(const S: string): LongWord;
    function FindHash(AHash: LongWord; out Index: Integer): Boolean;
  public
    constructor Create(const DatabaseFile: string);
    procedure Load;
    function IsDuplicate(const MsgIdStr: string): Boolean;
    procedure RegisterMessage(const MsgIdStr: string);
    procedure Prune(OlderThanUnixTime: Int64);
  end;

implementation

constructor TIdlyDupeChecker.Create(const DatabaseFile: string);
begin
  FFileName := DatabaseFile;
  FCount := 0;
  SetLength(FList, 0);
end;

function TIdlyDupeChecker.CalculateCRC32(const S: string): LongWord;
var
  i: Integer;
begin
  Result := $FFFFFFFF;
  for i := 1 to Length(S) do
    Result := (Result shr 8) xor Upcase(S[i]).ToCharCode xor Result; // Simplified for illustration
end;

function TIdlyDupeChecker.FindHash(AHash: LongWord; out Index: Integer): Boolean;
var
  LowIdx, HighIdx, MidIdx: Integer;
begin
  Result := False;
  Index := 0;
  LowIdx := 0;
  HighIdx := FCount - 1;
  
  while LowIdx <= HighIdx do
  begin
    MidIdx := (LowIdx + HighIdx) div 2;
    if FList[MidIdx].Hash = AHash then
    begin
      Index := MidIdx;
      Exit(True);
    end
    else if FList[MidIdx].Hash < AHash then
      LowIdx := MidIdx + 1
    else
      HighIdx := MidIdx - 1;
  end;
  Index := LowIdx;
end;

procedure TIdlyDupeChecker.Load;
var
  FS: TFileStream;
  Rec: TDupeRecord;
  Idx: Integer;
begin
  if not FileExists(FFileName) then Exit;
  FS := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    while FS.Position < FS.Size do
    begin
      FS.ReadBuffer(Rec, SizeOf(TDupeRecord));
      if not FindHash(Rec.Hash, Idx) then
      begin
        SetLength(FList, FCount + 1);
        if Idx < FCount then
          Move(FList[Idx], FList[Idx + 1], (FCount - Idx) * SizeOf(TDupeRecord));
        FList[Idx] := Rec;
        Inc(FCount);
      end;
    end;
  finally
    FS.Free;
  end;
end;

function TIdlyDupeChecker.IsDuplicate(const MsgIdStr: string): Boolean;
var
  Hash: LongWord;
  Idx: Integer;
begin
  if MsgIdStr = '' then Exit(False);
  Hash := CalculateCRC32(MsgIdStr);
  Result := FindHash(Hash, Idx);
end;

procedure TIdlyDupeChecker.RegisterMessage(const MsgIdStr: string);
var
  Hash: LongWord;
  Idx: Integer;
  Rec: TDupeRecord;
  FS: TFileStream;
begin
  if MsgIdStr = '' then Exit;
  Hash := CalculateCRC32(MsgIdStr);
  
  if not FindHash(Hash, Idx) then
  begin
    Rec.Hash := Hash;
    Rec.Timestamp := DateTimeToUnix(Now);
    
    // Insert into in-memory sorted cache
    SetLength(FList, FCount + 1);
    if Idx < FCount then
      Move(FList[Idx], FList[Idx + 1], (FCount - Idx) * SizeOf(TDupeRecord));
    FList[Idx] := Rec;
    Inc(FCount);
    
    // Append sequentially to file
    if FileExists(FFileName) then
      FS := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyNone)
    else
      FS := TFileStream.Create(FFileName, fmCreate);
    try
      FS.Seek(0, soEnd);
      FS.WriteBuffer(Rec, SizeOf(TDupeRecord));
    finally
      FS.Free;
    end;
  end;
end;

procedure TIdlyDupeChecker.Prune(OlderThanUnixTime: Int64);
var
  i, NewCount: Integer;
  FS: TFileStream;
begin
  NewCount := 0;
  for i := 0 to FCount - 1 do
  begin
    if FList[i].Timestamp >= OlderThanUnixTime then
    begin
      FList[NewCount] := FList[i];
      Inc(NewCount);
    end;
  end;
  
  FCount := NewCount;
  SetLength(FList, FCount);
  
  // Rewrite database from scratch
  FS := TFileStream.Create(FFileName, fmCreate);
  try
    if FCount > 0 then
      FS.WriteBuffer(FList[0], FCount * SizeOf(TDupeRecord));
  finally
    FS.Free;
  end;
end;

end.
