(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Core.pas                                          *)
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
  SysUtils, Classes, sockets, baseunix;

type
  PConnectionContext = ^TConnectionContext;
  TConnectionContext = record
    FD: TSocket;
    ProtocolHandler: TProcedure(Context: PConnectionContext) of object;
    Buffer: array[0..4095] of Byte;
    BufLen: Integer;
    // Protocol-specific state variables go here
  end;

  TIdlyEngine = class
  private
    FMasterSet: TFDSet;
    FReadSet: TFDSet;
    FMaxFD: TSocket;
    FActiveConnections: TFPList; // Stores PConnectionContext
    FRunning: Boolean;
    procedure HandleNewConnection(ListenFD: TSocket);
    procedure HandleClientActivity(Context: PConnectionContext);
    procedure CloseConnection(Context: PConnectionContext);
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterServer(Port: Word);
    procedure Run;
    procedure Stop;
  end;

implementation

constructor TIdlyEngine.Create;
begin
  fpFD_ZERO(FMasterSet);
  FActiveConnections := TFPList.Create;
  FMaxFD := 0;
  FRunning := False;
end;

destructor TIdlyEngine.Destroy;
var
  i: Integer;
begin
  Stop;
  for i := 0 to FActiveConnections.Count - 1 do
    Dispose(PConnectionContext(FActiveConnections[i]));
  FActiveConnections.Free;
  inherited Destroy;
end;

procedure TIdlyEngine.RegisterServer(Port: Word);
var
  ServerFD: TSocket;
  Addr: TInetSockAddr;
  OptVal: LongInt;
begin
  ServerFD := fpSocket(AF_INET, SOCK_STREAM, 0);
  if ServerFD = -1 then Exit;

  OptVal := 1;
  fpSetSockOpt(ServerFD, SOL_SOCKET, SO_REUSEADDR, @OptVal, SizeOf(OptVal));

  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr.s_addr := htonl(INADDR_ANY);

  if fpBind(ServerFD, @Addr, SizeOf(Addr)) = 0 then
  begin
    if fpListen(ServerFD, 128) = 0 then
    begin
      // Set to non-blocking mode
      fpSetSockOpt(ServerFD, SOL_SOCKET, SO_NONBLOCK, @OptVal, SizeOf(OptVal));
      fpFD_SET(ServerFD, FMasterSet);
      if ServerFD > FMaxFD then FMaxFD := ServerFD;
    end;
  end;
end;

procedure TIdlyEngine.Run;
var
  ReadyCount: Integer;
  Timeout: TTimeVal;
  i: Integer;
  Context: PConnectionContext;
begin
  FRunning := True;
  while FRunning do
  begin
    FReadSet := FMasterSet;
    
    // 100ms slice to keep loop responsive to stop flags
    Timeout.tv_sec := 0;
    Timeout.tv_usec := 100000; 

    ReadyCount := fpSelect(FMaxFD + 1, @FReadSet, nil, nil, @Timeout);

    if ReadyCount > 0 then
    begin
      // 1. Check for incoming server socket connections
      // (Iterate through known listening sockets registered in FMasterSet)
      
      // 2. Iterate backwards through active client descriptors to handle data
      for i := FActiveConnections.Count - 1 downto 0 do
      begin
        Context := PConnectionContext(FActiveConnections[i]);
        if fpFD_ISSET(Context^.FD, FReadSet) <> 0 then
        begin
          HandleClientActivity(Context);
        end;
      end;
    end;
  end;
end;

procedure TIdlyEngine.HandleClientActivity(Context: PConnectionContext);
var
  BytesRead: Integer;
begin
  BytesRead := fpRecv(Context^.FD, @Context^.Buffer[Context^.BufLen], SizeOf(Context^.Buffer) - Context^.BufLen, 0);
  
  if BytesRead <= 0 then
  begin
    // Connection closed by remote host or error occurred
    CloseConnection(Context);
  end;
end;

procedure TIdlyEngine.CloseConnection(Context: PConnectionContext);
begin
  fpClose(Context^.FD);
  fpFD_CLR(Context^.FD, FMasterSet);
  FActiveConnections.Remove(Context);
  Dispose(Context);
end;

procedure TIdlyEngine.Stop;
begin
  FRunning := False;
end;

end.
