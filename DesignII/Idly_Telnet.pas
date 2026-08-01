(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Telnet.pas                                        *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_telnet;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sockets, baseunix, idly_core;

type
  // 1. Inherit from abstract core class to encapsulate state
  TTelnetConnection = class(TIdlyConnection)
  private
    FState: Integer; // Specific Telnet IAC tracking states
  public
    procedure HandleRead; override;
  end;

  // 2. Implement Factory layout to produce instances cleanly
  TTelnetProtocolFactory = class(TInterfacedObject, IIdlyProtocolFactory)
  public
    function CreateConnection(ClientFD: TSocket): TIdlyConnection;
  end;

implementation

procedure TTelnetConnection.HandleRead;
var
  BytesRead: Integer;
begin
  BytesRead := fpRecv(FD, @Buffer[BufLen], SizeOf(Buffer) - BufLen, 0);
  if BytesRead > 0 then
  begin
    // Run telnet option parsing, command eco loop, or BinkP frame routing
    fpSend(FD, Pointer(#13#10'TelnetPlugin Echo> '), 22, 0);
  end;
end;

function TTelnetProtocolFactory.CreateConnection(ClientFD: TSocket): TIdlyConnection;
begin
  Result := TTelnetConnection.Create(ClientFD);
  // Send the initial clear-screen / Telnet IAC options negotiation string safely here
  fpSend(ClientFD, Pointer('Welcome to the Modulated Telnet Component'#13#10), 42, 0);
end;

end.
