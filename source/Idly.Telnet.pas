(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Telnet.pas                                        *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly.telnet;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sockets, baseunix, idly_core;

const
  // Telnet Protocol Constants
  TN_SE        = 240; // End of subnegotiation parameters
  TN_NOP       = 242; // No operation
  TN_DM        = 242; // Data mark
  TN_BRK       = 243; // Break
  TN_IP        = 244; // Interrupt Process
  TN_AO        = 245; // Abort Output
  TN_AYT       = 246; // Are You There
  TN_EC        = 247; // Erase Character
  TN_EL        = 248; // Erase Line
  TN_GA        = 249; // Go Ahead
  TN_SB        = 250; // Subnegotiation
  TN_WILL      = 251; // Desires to begin performing option
  TN_WONT      = 252; // Refuses to perform option
  TN_DO        = 253; // Requests option to be performed
  TN_DONT      = 254; // Demands option stop being performed
  TN_IAC       = 255; // Interpret As Command

  // Common Telnet Options
  TNO_BINARY   = 0;   // Binary Transmission
  TNO_ECHO     = 1;   // Echo
  TNO_SGA      = 3;   // Suppress Go Ahead

type
  TTelnetState = (tsNormal, tsIAC, tsWill, tsWont, tsDo, tsDont);

  TIdlyTelnetHandler = class
  private
    FState: TTelnetState;
    procedure SendCommand(FD: TSocket; Verb, Option: Byte);
    procedure ProcessByte(Context: PConnectionContext; B: Byte; var CleanBuf: array of Byte; var CleanLen: Integer);
  public
    constructor Create;
    procedure HandleTelnetRead(Context: PConnectionContext);
    procedure SendText(Context: PConnectionContext; const Msg: string);
  end;

implementation

constructor TIdlyTelnetHandler.Create;
begin
  FState := tsNormal;
end;

procedure TIdlyTelnetHandler.SendCommand(FD: TSocket; Verb, Option: Byte);
var
  Cmd: array[0..2] of Byte;
begin
  Cmd[0] := TN_IAC;
  Cmd[1] := Verb;
  Cmd[2] := Option;
  fpSend(FD, @Cmd[0], 3, 0);
end;

procedure TIdlyTelnetHandler.ProcessByte(Context: PConnectionContext; B: Byte; var CleanBuf: array of Byte; var CleanLen: Integer);
begin
  case FState of
    tsNormal:
      begin
        if B = TN_IAC then
          FState := tsIAC
        else
        begin
          CleanBuf[CleanLen] := B;
          Inc(CleanLen);
        end;
      end;
    tsIAC:
      begin
        case B of
          TN_IAC:  // Escaped IAC byte
            begin
              CleanBuf[CleanLen] := TN_IAC;
              Inc(CleanLen);
              FState := tsNormal;
            end;
          TN_WILL: FState := tsWill;
          TN_WONT: FState := tsWont;
          TN_DO:   FState := tsDo;
          TN_DONT: FState := tsDont;
        else
          FState := tsNormal; // Ignore other commands
        end;
      end;
    tsWill:
      begin
        // Client says: "I WILL do this". We reply DON'T unless it's binary/SGA
        if (B <> TNO_BINARY) and (B <> TNO_SGA) then
          SendCommand(Context^.FD, TN_DONT, B);
        FState := tsNormal;
      end;
    tsWont:
      begin
        FState := tsNormal;
      end;
    tsDo:
      begin
        // Client asks us: "Please DO this". We say WILL for Echo/SGA
        if (B = TNO_ECHO) or (B = TNO_SGA) or (B = TNO_BINARY) then
          SendCommand(Context^.FD, TN_WILL, B)
        else
          SendCommand(Context^.FD, TN_WONT, B);
        FState := tsNormal;
      end;
    tsDont:
      begin
        FState := tsNormal;
      end;
  end;
end;

procedure TIdlyTelnetHandler.HandleTelnetRead(Context: PConnectionContext);
var
  BytesRead: Integer;
  i: Integer;
  CleanBuf: array[0..4095] of Byte;
  CleanLen: Integer;
  LineStr: string;
begin
  CleanLen := 0;
  // Non-blocking read into context staging buffer
  BytesRead := fpRecv(Context^.FD, @Context^.Buffer[Context^.BufLen], SizeOf(Context^.Buffer) - Context^.BufLen, 0);
  
  if BytesRead <= 0 then Exit; // Core handles disconnects

  // State machine parse loop
  for i := 0 to BytesRead - 1 do
  begin
    ProcessByte(Context, Context^.Buffer[i], CleanBuf, CleanLen);
  end;

  if CleanLen > 0 then
  begin
    SetString(LineStr, PChar(@CleanBuf[0]), CleanLen);
    
    // Example Application Behavior: Raw BBS Mode Command Parsing
    // If user presses enter, parse the raw buffer command string
    if (Pos(#13, LineStr) > 0) or (Pos(#10, LineStr) > 0) then
    begin
      SendText(Context, #13#10'IDLY-BBS Engine Received Command: ' + Trim(LineStr) + #13#10'BBS>');
    end;
  end;
end;

procedure TIdlyTelnetHandler.SendText(Context: PConnectionContext; const Msg: string);
begin
  if Msg <> '' then
    fpSend(Context^.FD, Pointer(Msg), Length(Msg), 0);
end;

end.
