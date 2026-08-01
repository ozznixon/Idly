(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: idly.legacy.ftn.pas                                    *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_legacy_ftn;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sockets, baseunix, idly_core;

type
  TLegacyFTNProtocol = (ftnUnknown, ftnStoneAge, ftnYooHoo, ftnEMSI);

  TLegacyFTNConnection = class(TIdlyConnection)
  private
    FProtocolType: TLegacyFTNProtocol;
    procedure DetermineProtocol(const IncomingChunk: string);
    procedure HandleEMSI();
    procedure HandleYooHoo();
    procedure HandleStoneAge();
  public
    procedure HandleRead; override;
  end;

  TLegacyFTNFactory = class(TInterfacedObject, IIdlyProtocolFactory)
  public
    function CreateConnection(ClientFD: TSocket): TIdlyConnection;
  end;

implementation

function TLegacyFTNFactory.CreateConnection(ClientFD: TSocket): TIdlyConnection;
begin
  Result := TLegacyFTNConnection.Create(ClientFD);
end;

procedure TLegacyFTNConnection.DetermineProtocol(const IncomingChunk: string);
begin
  if Pos('**EMSI_REQ', IncomingChunk) > 0 then
  begin
    FProtocolType := ftnEMSI;
    HandleEMSI();
  end
  else if Pos('yohoo', LowerCase(IncomingChunk)) > 0 then
  begin
    FProtocolType := ftnYooHoo;
    HandleYooHoo();
  end
  else if Pos('**KEY', IncomingChunk) > 0 then
  begin
    FProtocolType := ftnStoneAge;
    HandleStoneAge();
  end;
end;

procedure TLegacyFTNConnection.HandleRead;
var
  BytesRead: Integer;
  RawDataString: string;
begin
  BytesRead := fpRecv(FD, @Buffer[BufLen], SizeOf(Buffer) - BufLen, 0);
  if BytesRead <= 0 then Exit;

  SetString(RawDataString, PChar(@Buffer[BufLen]), BytesRead);
  Inc(BufLen, BytesRead);

  if FProtocolType = ftnUnknown then
  begin
    DetermineProtocol(RawDataString);
  end else
  begin
    // Route state machine based on initialized handshakes
    case FProtocolType of
      ftnEMSI:     Writeln('Processing inbound EMSI stream packet data...');
      ftnYooHoo:   Writeln('Processing inbound YooHoo session data...');
      ftnStoneAge: Writeln('Processing inbound StoneAge terminal block flags...');
    end;
  end;
end;

procedure TLegacyFTNConnection.HandleEMSI;
var
  EMSIDatagram: string;
begin
  // Build a structurally valid EMSI_DAT response packet frame
  EMSIDatagram := '**EMSI_DAT 8F4E[00000]0000 [IdlyCore Engine] [Crestview, FL] [Ozz Nixon]**'#13;
  fpSend(FD, Pointer(EMSIDatagram), Length(EMSIDatagram), 0);
end;

procedure TLegacyFTNConnection.HandleYooHoo;
begin
  // Send the vintage yhoo response handshake trigger back to the remote mailer link
  fpSend(FD, Pointer('yhoo_ok'#13), 8, 0);
end;

procedure TLegacyFTNConnection.HandleStoneAge;
begin
  // Respond with traditional StoneAge carrier affirmation parameters
  fpSend(FD, Pointer('**ACK'#13), 6, 0);
end;

end.
