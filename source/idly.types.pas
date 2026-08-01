(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Types.pas                                         *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit Idly.Types;

{$mode objfpc}{$H+}{$J-}

interface

type
  IIdlyConnection = interface;

  { All RFC modules must implement this interface }
  IIdlyProtocolHandler = interface
    ['{A9B8C7D6-E5F4-4321-A1B2-C3D4E5F6A7B8}']
    function GetRFCNumber: Integer;
    function GetProtocolName: string;
    procedure OnConnect(const AConnection: IIdlyConnection);
    procedure OnDataReceived(const AConnection: IIdlyConnection; const ABuffer: pointer; const ALength: Integer);
    procedure OnDisconnect(const AConnection: IIdlyConnection);
  end;

  { Interface exposed by the core engine to the protocol handlers }
  IIdlyConnection = interface
    ['{12345678-ABCD-EF01-2345-6789ABCDEF01}']
    function GetConnectionID: Int64;
    procedure WriteData(const ABuffer: pointer; const ALength: Integer);
    procedure Disconnect;
    procedure SwitchProtocol(const ANewHandler: IIdlyProtocolHandler);
  end;

implementation

end.
