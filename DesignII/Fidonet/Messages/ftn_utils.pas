(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: FTN.Utils.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit ftn_utils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  BASE36_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

{ Appends a FidoNet structural Control-A kludge line directly to the body text block }
procedure AppendKludgeLine(var BodyText: string; const Token, Value: string);

{ Converts a standard numerical value to a clean Base36 alphanumeric string }
function IntToBase36(Value: LongWord; MinDigits: Integer = 0): string;

{ Converts a Base36 alphanumeric string back into a standard numerical value }
function Base36ToInt(const S: string): LongWord;

implementation

procedure AppendKludgeLine(var BodyText: string; const Token, Value: string);
begin
  // Control-A (#1) + Token + Value + Carriage Return (#13). 
  // Placed at the front of the body block according to FTN rules.
  BodyText := #1 + Trim(Token) + ': ' + Trim(Value) + #13 + BodyText;
end;

function IntToBase36(Value: LongWord; MinDigits: Integer = 0): string;
var
  Remainder: Byte;
begin
  Result := '';
  if Value = 0 then
    Result := '0'
  else
  begin
    while Value > 0 do
    begin
      Remainder := Value mod 36;
      Result := BASE36_CHARS[Remainder + 1] + Result;
      Value := Value div 36;
    end;
  end;

  // Pad out left characters with leading zeros if a minimum length is requested
  while Length(Result) < MinDigits do
    Result := '0' + Result;
end;

function Base36ToInt(const S: string): LongWord;
var
  i: Integer;
  UpperS: string;
  PosChar: Integer;
begin
  Result := 0;
  UpperS := UpperCase(Trim(S));
  
  for i := 1 to Length(UpperS) do
  begin
    PosChar := Pos(UpperS[i], BASE36_CHARS) - 1;
    if PosChar < 0 then
      raise EConvertError.CreateFmt('"%s" is not a valid Base36 character configuration.', [UpperS[i]]);
      
    Result := (Result * 36) + LongWord(PosChar);
  end;
end;

end.
