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
  SysUtils, Classes, sockets, baseunix, linux; // Added linux unit for epoll

type
  PConnectionContext = ^TConnectionContext;
  TConnectionContext = record
    FD: TSocket;
    ProtocolHandler: TProcedure(Context: PConnectionContext) of object;
    Buffer: array[0..4095] of Byte;
    BufLen: Integer;
  end;

  TIdlyEngine = class
  private
    FEpollFD: Integer;
    FActiveConnections: TFPList;
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
  // Create the epoll instance
  FEpollFD := epoll_create(1);
  if FEpollFD = -1 then
    raise Exception.Create('Failed to initialize epoll context.');
    
  FActiveConnections := TFPList.Create;
  FRunning := False;
end;

destructor TIdlyEngine.Destroy;
begin
  Stop;
  FActiveConnections.Free;
  if FEpollFD <> -1 then fpClose(FEpollFD);
  inherited Destroy;
end;

procedure TIdlyEngine.RegisterServer(Port: Word);
var
  ServerFD: TSocket;
  Addr: TInetSockAddr;
  OptVal: LongInt;
  EV: tepoll_event;
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
      // Set server listening socket to non-blocking
      fpSetSockOpt(ServerFD, SOL_SOCKET, SO_NONBLOCK, @OptVal, SizeOf(OptVal));
      
      // Register server socket with epoll for read events (EPOLLIN)
      EV.events := EPOLLIN;
      EV.data.fd := ServerFD; // Target descriptor
      
      if epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ServerFD, @EV) < 0 then
        raise Exception.Create('Failed to add server socket to epoll.');
    end;
  end;
end;

procedure TIdlyEngine.Run;
var
  EventBuffer: array[0..63] of tepoll_event; // Batch up to 64 events per cycle
  ReadyCount: Integer;
  i: Integer;
  Context: PConnectionContext;
begin
  FRunning := True;
  while FRunning do
  begin
    // 100ms timeout window to keep the loop responsive to termination flags
    ReadyCount := epoll_wait(FEpollFD, @EventBuffer[0], 64, 100);

    for i := 0 to ReadyCount - 1 do
    begin
      // If the event matches a listening server socket, you would call HandleNewConnection.
      // For existing clients, data.ptr holds our specific Context record pointer.
      if (EventBuffer[i].events and EPOLLIN) <> 0 then
      begin
        // If it is an active client tracking its context layout:
        Context := PConnectionContext(EventBuffer[i].data.ptr);
        HandleClientActivity(Context);
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
    CloseConnection(Context);
  end;
end;

procedure TIdlyEngine.CloseConnection(Context: PConnectionContext);
begin
  // Linux automatically drops FDs from epoll sets on close, 
  // but explicitly calling EPOLL_CTL_DEL protects state consistency.
  epoll_ctl(FEpollFD, EPOLL_CTL_DEL, Context^.FD, nil);
  fpClose(Context^.FD);
  FActiveConnections.Remove(Context);
  Dispose(Context);
end;

procedure TIdlyEngine.Stop;
begin
  FRunning := False;
end;

end.
