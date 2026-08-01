(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.RFC865.pas                                        *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit Idly.RFC865;

{$mode objfpc}{$H+}{$J-}

interface

uses
  Idly.Types;

type
  { Simple RFC 865 Implementation }
  TIdlyQOTDHandler = class(TInterfacedObject, IIdlyProtocolHandler)
  public
    function GetRFCNumber: Integer;
    function GetProtocolName: string;
    procedure OnConnect(const AConnection: IIdlyConnection);
    procedure OnDataReceived(const AConnection: IIdlyConnection; const ABuffer: pointer; const ALength: Integer);
    procedure OnDisconnect(const AConnection: IIdlyConnection);
  end;

implementation

function TIdlyQOTDHandler.GetRFCNumber: Integer;
begin
  Result := 865;
end;

function TIdlyQOTDHandler.GetProtocolName: string;
begin
  Result := 'QOTD';
end;

procedure TIdlyQOTDHandler.OnConnect(const AConnection: IIdlyConnection);
var
  Quote: string;
begin
  Quote := 'Idly Network Suite: Real scalability uses fewer threads.' + #13#10;
  AConnection.WriteData(@Quote[1], Length(Quote));
  AConnection.Disconnect;
end;

procedure TIdlyQOTDHandler.OnDataReceived(const AConnection: IIdlyConnection; const ABuffer: pointer; const ALength: Integer);
begin
  { QOTD discards any incoming client payload }
end;

procedure TIdlyQOTDHandler.OnDisconnect(const AConnection: IIdlyConnection);
begin
  // Handle cleanup
end;

end.
