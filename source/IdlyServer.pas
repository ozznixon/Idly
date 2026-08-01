(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: IdlyServer.pas                                         *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
program IdlyServer;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  Idly.Core,
  Idly.Types,
  Idly.RFC865;

var
  Engine: TIdlyEngine;
  QOTDHandler: IIdlyProtocolHandler;
begin
  Engine := TIdlyEngine.Create;
  QOTDHandler := TIdlyQOTDHandler.Create;
  try
    { Bind RFC 865 to port 17 }
    Engine.RegisterRFC(17, QOTDHandler);
    
    WriteLn('Idly Socket Suite Initialized. Listening for RFC implementations...');
    // Engine.Start; // Uncomment once event loop system hooks are defined
  finally
    Engine.Free;
  end;
end.
