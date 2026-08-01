(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Linker.pas                                        *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_linker;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, idly_msg;

type
  TMessageMapItem = record
    MsgNum: Word;
    MsgID: string;
    ReplyID: string;
  end;

procedure LinkMessageDirectory(const DirectoryPath: string);

implementation

function ExtractKludgeValue(const BodyText, Token: string): string;
var
  P, EndP: Integer;
  LookFor: string;
begin
  Result := '';
  LookFor := #1 + Token + ':';
  P := Pos(LookFor, BodyText);
  if P > 0 then
  begin
    Inc(P, Length(LookFor));
    EndP := P;
    while (EndP <= Length(BodyText)) and (BodyText[EndP] <> #13) and (BodyText[EndP] <> #10) do
      Inc(EndP);
    Result := Trim(Copy(BodyText, P, EndP - P));
  end;
end;

procedure LinkMessageDirectory(const DirectoryPath: string);
var
  SR: TSearchRec;
  MsgData: TFTNMessageData;
  Map: array of TMessageMapItem;
  Count: Integer;
  i, j: Integer;
  FilePath: string;
  Hdr: TMSGHeader;
  FS: TFileStream;
begin
  Count := 0;
  SetLength(Map, 0);
  
  // Phase 1: Scan directory and cache identifiers
  if FindFirst(IncludeTrailingPathDelimiter(DirectoryPath) + '*.msg', faAnyFile, SR) = 0 then
  begin
    repeat
      FilePath := IncludeTrailingPathDelimiter(DirectoryPath) + SR.Name;
      if TIdlyOpusMsgEngine.ReadMessage(FilePath, MsgData) then
      begin
        SetLength(Map, Count + 1);
        Map[Count].MsgNum := StrToIntDef(ChangeFileExt(SR.Name, ''), 0);
        Map[Count].MsgID := ExtractKludgeValue(MsgData.BodyText, 'MSGID');
        Map[Count].ReplyID := ExtractKludgeValue(MsgData.BodyText, 'REPLY');
        Inc(Count);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  // Phase 2: Interlink matching nodes and update file headers
  for i := 0 to Count - 1 do
  begin
    for j := 0 to Count - 1 do
    begin
      if (Map[i].ReplyID <> '') and (Map[i].ReplyID = Map[j].MsgID) then
      begin
        FilePath := IncludeTrailingPathDelimiter(DirectoryPath) + IntToStr(Map[i].MsgNum) + '.msg';
        
        // Open file, modify link offsets directly, write back
        FS := TFileStream.Create(FilePath, fmOpenReadWrite or fmShareDenyWrite);
        try
          FS.ReadBuffer(Hdr, SizeOf(TMSGHeader));
          Hdr.ReplyTo := Map[j].MsgNum; // This message points to its parent
          FS.Seek(0, soFromBeginning);
          FS.WriteBuffer(Hdr, SizeOf(TMSGHeader));
        finally
          FS.Free;
        end;

        // Also update parent record's next node leaf reference
        FilePath := IncludeTrailingPathDelimiter(DirectoryPath) + IntToStr(Map[j].MsgNum) + '.msg';
        FS := TFileStream.Create(FilePath, fmOpenReadWrite or fmShareDenyWrite);
        try
          FS.ReadBuffer(Hdr, SizeOf(TMSGHeader));
          Hdr.NextReply := Map[i].MsgNum; // Parent points to its child sequence leaf
          FS.Seek(0, soFromBeginning);
          FS.WriteBuffer(Hdr, SizeOf(TMSGHeader));
        finally
          FS.Free;
        end;
      end;
    end;
  end;
end;

end.
