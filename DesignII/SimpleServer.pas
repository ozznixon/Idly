(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Core.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
program idly.Simple.Server;

{$mode objfpc}{$H+}

uses
  idly_core, idly_telnet;

var
  Engine: TIdlyEngine;

begin
  Engine := TIdlyEngine.Create;
  try
    // Register Telnet on port 23, completely driving it via factory injection
    Engine.RegisterProtocol(23, TTelnetProtocolFactory.Create);
    
    // You can add an HTTP component or a FidoNet Mailer onto another port here seamlessly:
    // Engine.RegisterProtocol(80, THttpProtocolFactory.Create);
    // Engine.RegisterProtocol(24554, TBinkPProtocolFactory.Create);

    Writeln('Idly multi-protocol framework running on desktop loop...');
    Engine.Run;
  finally
    Engine.Free;
  end;
end.
