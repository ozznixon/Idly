(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.BinkP.pas                                         *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_binkp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sockets, baseunix, idly_core;

const
  BINKP_CMD_SYS    = 0;
  BINKP_CMD_ZVER   = 1;
  BINKP_CMD_ADR    = 2;
  BINKP_CMD_PWD    = 3;
  BINKP_CMD_FILE   = 4;
  BINKP_CMD_OK     = 5;

type
  TBinkPState = (bpHandshake, bpTransfer, bpDone);

  TBinkPConnection = class(TIdlyConnection)
  private
    FState: TBinkPState;
    procedure ParseFrame(CommandByte: Byte; FrameData: Pointer; DataLen: Integer);
    procedure SendCommand(Cmd: Byte; const Payload: string);
  public
    constructor Create(AFileDescriptor: TSocket); override;
    procedure HandleRead; override;
  end;

  TBinkPProtocolFactory = class(TInterfacedObject, IIdlyProtocolFactory)
  public
    function CreateConnection(ClientFD: TSocket): TIdlyConnection;
  end;

implementation

constructor TBinkPConnection.Create(AFileDescriptor: TSocket);
begin
  inherited Create(AFileDescriptor);
  FState := bpHandshake;
end;

procedure TBinkPConnection.SendCommand(Cmd: Byte; const Payload: string);
var
  FrameLen: Word;
  Header: array[0..1] of Byte;
begin
  FrameLen := Length(Payload) + 1;
  // BinkP frames hide the command bit inside the high order length bits
  Header[0] := (FrameLen shr 8) or $80; // $80 flags this explicitly as a command frame
  Header[1] := FrameLen and $FF;
  
  fpSend(FD, @Header, 2, 0);
  fpSend(FD, @Cmd, 1, 0);
  if Length(Payload) > 0 then
    fpSend(FD, Pointer(Payload), Length(Payload), 0);
end;

procedure TBinkPConnection.ParseFrame(CommandByte: Byte; FrameData: Pointer; DataLen: Integer);
var
  PayloadText: string;
begin
  if DataLen > 0 then
    SetString(PayloadText, PChar(FrameData), DataLen);

  case CommandByte of
    BINKP_CMD_SYS: SendCommand(BINKP_CMD_ZVER, 'IdlyCore v1.1');
    BINKP_CMD_ADR: SendCommand(BINKP_CMD_PWD, 'PlaintextPasswordMatched');
    BINKP_CMD_OK:  FState := bpTransfer;
  end;
end;

procedure TBinkPConnection.HandleRead;
var
  BytesRead: Integer;
  FrameLength: Word;
  IsCommand: Boolean;
begin
  BytesRead := fpRecv(FD, @Buffer[BufLen], SizeOf(Buffer) - BufLen, 0);
  if BytesRead <= 0 then Exit;
  Inc(BufLen, BytesRead);

  // Parse frames sequentially while staging array boundary criteria match
  while BufLen >= 2 do
  begin
    IsCommand := (Buffer[0] and $80) <> 0;
    FrameLength := ((Buffer[0] and $7F) shl 8) or Buffer[1];

    if BufLen < (2 + FrameLength) then Exit; // Frame incomplete, await remaining fragments

    if IsCommand and (FrameLength > 0) then
      ParseFrame(Buffer[2], @Buffer[3], FrameLength - 1);

    // Consume structural bytes from our buffer
    Move(Buffer[2 + FrameLength], Buffer[0], BufLen - (2 + FrameLength));
    Dec(BufLen, 2 + FrameLength);
  end;
end;

function TBinkPProtocolFactory.CreateConnection(ClientFD: TSocket): TIdlyConnection;
var
  Conn: TBinkPConnection;
begin
  Conn := TBinkPConnection.Create(ClientFD);
  // Send out initial BinkP greeting string structure
  Conn.SendCommand(BINKP_CMD_SYS, 'SYS IdlyCoreMailer');
  Conn.SendCommand(BINKP_CMD_ADR, 'ADR 1:3603/999@fidonet');
  Result := Conn;
end;

end.
