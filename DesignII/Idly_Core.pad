(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly_Core.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
unit idly_core;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, sockets, baseunix
  {$IFDEF LINUX}, linux{$ENDIF}
  {$IFDEF DARWIN}, kqueue{$ENDIF};

type
  TIdlyEngine = class; // Forward declaration

  // Abstract base class for protocol-specific connection contexts
  TIdlyConnection = class
  public
    FD: TSocket;
    Buffer: array[0..4095] of Byte;
    BufLen: Integer;
    constructor Create(AFileDescriptor: TSocket); virtual;
    destructor Destroy; override;
    // Core event triggered when raw data arrives on the socket
    procedure HandleRead; virtual; abstract;
  end;
  TIdlyConnectionClass = class of TIdlyConnection;

  // Interface that plugins implement to handle handshakes on a specific port
  IIdlyProtocolFactory = interface
    ['{8F4E67A2-1234-5678-ABCD-EF1234567890}']
    function CreateConnection(ClientFD: TSocket): TIdlyConnection;
  end;

  // The engine registry mapping record
  TListenerBinding = record
    Port: Word;
    ServerFD: TSocket;
    Factory: IIdlyProtocolFactory;
  end;

  TIdlyEngine = class
  private
    FBindings: array of TListenerBinding;
    FActiveConnections: TFPList;
    FRunning: Boolean;
    {$IFDEF LINUX}FEpollFD: Integer;{$ENDIF}
    {$IFDEF DARWIN}FKQueueFD: Integer;{$ENDIF}
    {$IFNDEF LINUX}{$IFNDEF DARWIN}FMasterSet: TFDSet; FReadSet: TFDSet; FMaxFD: TSocket;{$ENDIF}{$ENDIF}

    procedure HandleNewConnection(ListenFD: TSocket; const Factory: IIdlyProtocolFactory);
    procedure CloseConnection(Connection: TIdlyConnection);
  public
    constructor Create;
    destructor Destroy; override;
    // Register any server plugin cleanly without core modifications
    procedure RegisterProtocol(Port: Word; const Factory: IIdlyProtocolFactory);
    procedure Run;
    procedure Stop;
  end;
