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
  SysUtils, Classes, sockets, baseunix
  {$IFDEF LINUX}
  , linux // Native epoll for Debian/Linux
  {$ENDIF}
  {$IFDEF DARWIN}
  , kqueue // Native kqueue for macOS
  {$ENDIF}
  ;

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
    FActiveConnections: TFPList;
    FRunning: Boolean;
    
    // Platform-dependent properties
    {$IFDEF LINUX}
    FEpollFD: Integer;
    {$ENDIF}
    {$IFDEF DARWIN}
    FKQueueFD: Integer;
    {$ENDIF}
    {$IFNDEF LINUX}
      {$IFNDEF DARWIN}
      FMasterSet: TFDSet;
      FReadSet: TFDSet;
      FMaxFD: TSocket;
      {$ENDIF}
    {$ENDIF}

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
  FActiveConnections := TFPList.Create;
  FRunning := False;

  {$IFDEF LINUX}
  FEpollFD := epoll_create(1);
  if FEpollFD = -1 then raise Exception.Create('Failed to initialize epoll context.');
  {$ENDIF}

  {$IFDEF DARWIN}
  FKQueueFD := kqueue();
  if FKQueueFD = -1 then raise Exception.Create('Failed to initialize kqueue context.');
  {$ENDIF}

  {$IFNDEF LINUX}
    {$IFNDEF DARWIN}
    fpFD_ZERO(FMasterSet);
    FMaxFD := 0;
    {$ENDIF}
  {$ENDIF}
end;

destructor TIdlyEngine.Destroy;
begin
  Stop;
  FActiveConnections.Free;
  
  {$IFDEF LINUX}
  if FEpollFD <> -1 then fpClose(FEpollFD);
  {$ENDIF}
  
  {$IFDEF DARWIN}
  if FKQueueFD <> -1 then fpClose(FKQueueFD);
  {$ENDIF}
  
  inherited Destroy;
end;

procedure TIdlyEngine.RegisterServer(Port: Word);
var
  ServerFD: TSocket;
  Addr: TInetSockAddr;
  OptVal: LongInt;
  {$IFDEF LINUX}
  EV: tepoll_event;
  {$ENDIF}
  {$IFDEF DARWIN}
  EV: struct_kevent;
  {$ENDIF}
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
      fpSetSockOpt(ServerFD, SOL_SOCKET, SO_NONBLOCK, @OptVal, SizeOf(OptVal));

      {$IFDEF LINUX}
      EV.events := EPOLLIN;
      EV.data.fd := ServerFD;
      epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ServerFD, @EV);
      {$ENDIF}

      {$IFDEF DARWIN}
      EV.ident := ServerFD;
      EV.filter := EVFILT_READ;
      EV.flags := EV_ADD or EV_ENABLE;
      EV.fflags := 0;
      EV.data := 0;
      EV.udata := nil;
      kevent(FKQueueFD, @EV, 1, nil, 0, nil);
      {$ENDIF}

      {$IFNDEF LINUX}
        {$IFNDEF DARWIN}
        fpFD_SET(ServerFD, FMasterSet);
        if ServerFD > FMaxFD then FMaxFD := ServerFD;
        {$ENDIF}
      {$ENDIF}
    end;
  end;
end;

procedure TIdlyEngine.Run;
var
  i: Integer;
  ReadyCount: Integer;
  Context: PConnectionContext;
  {$IFDEF LINUX}
  EventBuffer: array[0..63] of tepoll_event;
  {$ENDIF}
  {$IFDEF DARWIN}
  EventBuffer: array[0..63] of struct_kevent;
  TimeoutSpec: timespec;
  {$ENDIF}
  {$IFNDEF LINUX}
    {$IFNDEF DARWIN}
    TimeoutVal: TTimeVal;
    {$ENDIF}
  {$ENDIF}
begin
  FRunning := True;
  while FRunning do
  begin
    {$IFDEF LINUX}
    ReadyCount := epoll_wait(FEpollFD, @EventBuffer, 64, 100);
    for i := 0 to ReadyCount - 1 do
    begin
      if (EventBuffer[i].events and EPOLLIN) <> 0 then
      begin
        Context := PConnectionContext(EventBuffer[i].data.ptr);
        if Context <> nil then HandleClientActivity(Context);
      end;
    end;
    {$ENDIF}

    {$IFDEF DARWIN}
    TimeoutSpec.tv_sec := 0;
    TimeoutSpec.tv_nsec := 100000000; // 100ms
    ReadyCount := kevent(FKQueueFD, nil, 0, @EventBuffer, 64, @TimeoutSpec);
    for i := 0 to ReadyCount - 1 do
    begin
      if EventBuffer[i].filter = EVFILT_READ then
      begin
        Context := PConnectionContext(EventBuffer[i].udata);
        if Context <> nil then HandleClientActivity(Context);
      end;
    end;
    {$ENDIF}

    {$IFNDEF LINUX}
      {$IFNDEF DARWIN}
      FReadSet := FMasterSet;
      TimeoutVal.tv_sec := 0;
      TimeoutVal.tv_usec := 100000;
      ReadyCount := fpSelect(FMaxFD + 1, @FReadSet, nil, nil, @TimeoutVal);
      if ReadyCount > 0 then
      begin
        for i := FActiveConnections.Count - 1 downto 0 do
        begin
          Context := PConnectionContext(FActiveConnections[i]);
          if fpFD_ISSET(Context^.FD, FReadSet) <> 0 then HandleClientActivity(Context);
        end;
      end;
      {$ENDIF}
    {$ENDIF}
  end;
end;

procedure TIdlyEngine.HandleClientActivity(Context: PConnectionContext);
var
  BytesRead: Integer;
begin
  BytesRead := fpRecv(Context^.FD, @Context^.Buffer[Context^.BufLen], SizeOf(Context^.Buffer) - Context^.BufLen, 0);
  if BytesRead <= 0 then
    CloseConnection(Context);
end;

procedure TIdlyEngine.CloseConnection(Context: PConnectionContext);
begin
  {$IFDEF LINUX}
  epoll_ctl(FEpollFD, EPOLL_CTL_DEL, Context^.FD, nil);
  {$ENDIF}
  
  {$IFDEF DARWIN}
  // kqueue automatically removes closing descriptors
  {$ENDIF}
  
  {$IFNDEF LINUX}
    {$IFNDEF DARWIN}
    fpFD_CLR(Context^.FD, FMasterSet);
    {$ENDIF}
  {$ENDIF}

  fpClose(Context^.FD);
  FActiveConnections.Remove(Context);
  Dispose(Context);
end;

procedure TIdlyEngine.Stop;
begin
  FRunning := False;
end;

end.
