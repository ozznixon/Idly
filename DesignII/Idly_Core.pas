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
  {$IFDEF DARWIN}, kqueue{$ENDIF}; // Exposes struct_kevent and kevent() on macOS

type
  TIdlyEngine = class;

  TIdlyConnection = class
  public
    FD: TSocket;
    Buffer: array[0..4095] of Byte;
    BufLen: Integer;
    constructor Create(AFileDescriptor: TSocket); virtual;
    destructor Destroy; override;
    procedure HandleRead; virtual; abstract;
  end;

  IIdlyProtocolFactory = interface
    ['{8F4E67A2-1234-5678-ABCD-EF1234567890}']
    function CreateConnection(ClientFD: TSocket): TIdlyConnection;
  end;

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
    function IsListenerFD(AValue: TSocket; out OutFactory: IIdlyProtocolFactory): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterProtocol(Port: Word; const Factory: IIdlyProtocolFactory);
    procedure Run;
    procedure Stop;
  end;

implementation

constructor TIdlyConnection.Create(AFileDescriptor: TSocket);
begin
  FD := AFileDescriptor;
  BufLen := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);
end;

destructor TIdlyConnection.Destroy; begin inherited Destroy; end;

constructor TIdlyEngine.Create;
begin
  FActiveConnections := TFPList.Create;
  FRunning := False;

  {$IFDEF LINUX}
  FEpollFD := epoll_create(1);
  if FEpollFD = -1 then raise Exception.Create('Failed to initialize epoll.');
  {$ENDIF}

  {$IFDEF DARWIN}
  FKQueueFD := kqueue();
  if FKQueueFD = -1 then raise Exception.Create('Failed to initialize kqueue.');
  {$ENDIF}

  {$IFNDEF LINUX}{$IFNDEF DARWIN}
  fpFD_ZERO(FMasterSet);
  FMaxFD := 0;
  {$ENDIF}{$ENDIF}
end;

destructor TIdlyEngine.Destroy;
var
  i: Integer;
begin
  Stop;
  for i := FActiveConnections.Count - 1 downto 0 do
    CloseConnection(TIdlyConnection(FActiveConnections[i]));
  FActiveConnections.Free;

  {$IFDEF LINUX}if FEpollFD <> -1 then fpClose(FEpollFD);{$ENDIF}
  {$IFDEF DARWIN}if FKQueueFD <> -1 then fpClose(FKQueueFD);{$ENDIF}
  inherited Destroy;
end;

function TIdlyEngine.IsListenerFD(AValue: TSocket; out OutFactory: IIdlyProtocolFactory): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FBindings) do
  begin
    if FBindings[i].ServerFD = AValue then
    begin
      OutFactory := FBindings[i].Factory;
      Exit(True);
    end;
  end;
end;

procedure TIdlyEngine.RegisterProtocol(Port: Word; const Factory: IIdlyProtocolFactory);
var
  ServerFD: TSocket;
  Addr: TInetSockAddr;
  OptVal: LongInt;
  Idx: Integer;
  {$IFDEF LINUX}EV: tepoll_event;{$ENDIF}
  {$IFDEF DARWIN}EV: struct_kevent;{$ENDIF}
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

      Idx := Length(FBindings);
      SetLength(FBindings, Idx + 1);
      FBindings[Idx].Port := Port;
      FBindings[Idx].ServerFD := ServerFD;
      FBindings[Idx].Factory := Factory;

      {$IFDEF LINUX}
      EV.events := EPOLLIN;
      EV.data.fd := ServerFD;
      epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ServerFD, @EV);
      {$ENDIF}

      {$IFDEF DARWIN}
      // Configure kqueue event for the incoming socket listener
      EV.ident := ServerFD;
      EV.filter := EVFILT_READ;
      EV.flags := EV_ADD or EV_ENABLE;
      EV.fflags := 0; EV.data := 0; 
      EV.udata := nil; // Explicitly nil out udata to label it a server hook
      if kevent(FKQueueFD, @EV, 1, nil, 0, nil) < 0 then
        raise Exception.Create('kqueue failed to bind server socket.');
      {$ENDIF}

      {$IFNDEF LINUX}{$IFNDEF DARWIN}
      fpFD_SET(ServerFD, FMasterSet);
      if ServerFD > FMaxFD then FMaxFD := ServerFD;
      {$ENDIF}{$ENDIF}
    end;
  end;
end;

procedure TIdlyEngine.HandleNewConnection(ListenFD: TSocket; const Factory: IIdlyProtocolFactory);
var
  ClientFD: TSocket;
  Addr: TInetSockAddr;
  AddrLen: TSockLen;
  OptVal: LongInt;
  Connection: TIdlyConnection;
  {$IFDEF LINUX}EV: tepoll_event;{$ENDIF}
  {$IFDEF DARWIN}EV: struct_kevent;{$ENDIF}
begin
  AddrLen := SizeOf(Addr);
  ClientFD := fpAccept(ListenFD, @Addr, @AddrLen);
  if ClientFD = -1 then Exit;

  OptVal := 1;
  fpSetSockOpt(ClientFD, SOL_SOCKET, SO_NONBLOCK, @OptVal, SizeOf(OptVal));

  Connection := Factory.CreateConnection(ClientFD);
  FActiveConnections.Add(Connection);

  {$IFDEF LINUX}
  EV.events := EPOLLIN or EPOLLET;
  EV.data.ptr := Connection;
  epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ClientFD, @EV);
  {$ENDIF}

  {$IFDEF DARWIN}
  // Register client connection to trigger read loops
  EV.ident := ClientFD;
  EV.filter := EVFILT_READ;
  EV.flags := EV_ADD or EV_ENABLE or EV_CLEAR; // EV_CLEAR acts as edge-triggered behavior
  EV.fflags := 0; EV.data := 0;
  EV.udata := Connection; // Pass connection object reference straight into kqueue
  kevent(FKQueueFD, @EV, 1, nil, 0, nil);
  {$ENDIF}

  {$IFNDEF LINUX}{$IFNDEF DARWIN}
  fpFD_SET(ClientFD, FMasterSet);
  if ClientFD > FMaxFD then FMaxFD := ClientFD;
  {$ENDIF}{$ENDIF}
end;

procedure TIdlyEngine.CloseConnection(Connection: TIdlyConnection);
begin
  {$IFDEF LINUX}epoll_ctl(FEpollFD, EPOLL_CTL_DEL, Connection.FD, nil);{$ENDIF}
  // Note: macOS kqueue automatically purges closed descriptors from its queue arrays
  
  {$IFNDEF LINUX}{$IFNDEF DARWIN}
  fpFD_CLR(Connection.FD, FMasterSet);
  {$ENDIF}{$ENDIF}

  fpClose(Connection.FD);
  FActiveConnections.Remove(Connection);
  Connection.Free;
end;

procedure TIdlyEngine.Run;
var
  i: Integer;
  ReadyCount: Integer;
  MatchedFactory: IIdlyProtocolFactory;
  ConnectionInstance: TIdlyConnection;
  {$IFDEF LINUX}EventBuffer: array[0..63] of tepoll_event;{$ENDIF}
  {$IFDEF DARWIN}
  EventBuffer: array[0..63] of struct_kevent;
  TimeoutSpec: timespec;
  {$ENDIF}
  {$IFNDEF LINUX}{$IFNDEF DARWIN}
  TimeoutVal: TTimeVal; j: Integer;
  {$ENDIF}{$ENDIF}
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
        if IsListenerFD(EventBuffer[i].data.fd, MatchedFactory) then
          HandleNewConnection(EventBuffer[i].data.fd, MatchedFactory)
        else
        begin
          ConnectionInstance := TIdlyConnection(EventBuffer[i].data.ptr);
          if ConnectionInstance <> nil then ConnectionInstance.HandleRead;
        end;
      end;
    end;
    {$ENDIF}

    {$IFDEF DARWIN}
    TimeoutSpec.tv_sec := 0;
    TimeoutSpec.tv_nsec := 100000000; // 100ms cycle timeout window
    ReadyCount := kevent(FKQueueFD, nil, 0, @EventBuffer, 64, @TimeoutSpec);
    
    for i := 0 to ReadyCount - 1 do
    begin
      // Filter out connection drops or standard errors explicitly
      if (EventBuffer[i].flags and EV_ERROR) <> 0 then Continue;

      if EventBuffer[i].filter = EVFILT_READ then
      begin
        // If udata is nil, this event signifies an incoming listener endpoint action
        if EventBuffer[i].udata = nil then
        begin
          if IsListenerFD(EventBuffer[i].ident, MatchedFactory) then
            HandleNewConnection(EventBuffer[i].ident, MatchedFactory);
        end
        else
        begin
          // Safely cast udata straight back into our connection object model
          ConnectionInstance := TIdlyConnection(EventBuffer[i].udata);
          ConnectionInstance.HandleRead;
        end;
      end;
    end;
    {$ENDIF}

    {$IFNDEF LINUX}{$IFNDEF DARWIN}
    FReadSet := FMasterSet; TimeoutVal.tv_sec := 0; TimeoutVal.tv_usec := 100000;
    ReadyCount := fpSelect(FMaxFD + 1, @FReadSet, nil, nil, @TimeoutVal);
    if ReadyCount > 0 then
    begin
      for i := 0 to High(FBindings) do
      begin
        if fpFD_ISSET(FBindings[i].ServerFD, FReadSet) <> 0 then
          HandleNewConnection(FBindings[i].ServerFD, FBindings[i].Factory);
      end;
      for j := FActiveConnections.Count - 1 downto 0 do
      begin
        ConnectionInstance := TIdlyConnection(FActiveConnections[j]);
        if fpFD_ISSET(ConnectionInstance.FD, FReadSet) <> 0 then
          ConnectionInstance.HandleRead;
      end;
    end;
    {$ENDIF}{$ENDIF}
  end;
end;

procedure TIdlyEngine.Stop; begin FRunning := False; end;

end.
