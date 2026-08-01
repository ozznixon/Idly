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

implementation
{  Implement the Decoupled Connection Handler (Idly.Core.pas)

   Update the engine's internal HandleNewConnection and event loop processing to act completely agnostic of the protocol type.
}
constructor TIdlyConnection.Create(AFileDescriptor: TSocket);
begin
  FD := AFileDescriptor;
  BufLen := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);
end;

destructor TIdlyConnection.Destroy;
begin
  inherited Destroy;
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
      EV.data.fd := ServerFD; // Using fd tracking for listener endpoints
      epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ServerFD, @EV);
      {$ENDIF}

      {$IFDEF DARWIN}
      EV.ident := ServerFD;
      EV.filter := EVFILT_READ;
      EV.flags := EV_ADD or EV_ENABLE;
      EV.fflags := 0; EV.data := 0; EV.udata := nil;
      kevent(FKQueueFD, @EV, 1, nil, 0, nil);
      {$ENDIF}
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

  // The factory creates the class instance mapping the correct protocol states
  Connection := Factory.CreateConnection(ClientFD);
  FActiveConnections.Add(Connection);

  {$IFDEF LINUX}
  EV.events := EPOLLIN or EPOLLET;
  EV.data.ptr := Connection; // Pass instance object pointer straight through
  epoll_ctl(FEpollFD, EPOLL_CTL_ADD, ClientFD, @EV);
  {$ENDIF}

  {$IFDEF DARWIN}
  EV.ident := ClientFD;
  EV.filter := EVFILT_READ;
  EV.flags := EV_ADD or EV_ENABLE;
  EV.fflags := 0; EV.data := 0;
  EV.udata := Connection;
  kevent(FKQueueFD, @EV, 1, nil, 0, nil);
  {$ENDIF}
end;

procedure TIdlyEngine.Run;
var
  i, j: Integer;
  ReadyCount: Integer;
  IsListener: Boolean;
  ConnectionInstance: TIdlyConnection;
  {$IFDEF LINUX}EventBuffer: array[0..63] of tepoll_event;{$ENDIF}
  {$IFDEF DARWIN}EventBuffer: array[0..63] of struct_kevent; TimeoutSpec: timespec;{$ENDIF}
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
        IsListener := False;
        // Verify if event comes from a registered listening server socket
        for j := 0 to High(FBindings) do
        begin
          if FBindings[j].ServerFD = EventBuffer[i].data.fd then
          begin
            HandleNewConnection(FBindings[j].ServerFD, FBindings[j].Factory);
            IsListener := True;
            Break;
          end;
        end;

        if not IsListener then
        begin
          ConnectionInstance := TIdlyConnection(EventBuffer[i].data.ptr);
          if ConnectionInstance <> nil then ConnectionInstance.HandleRead;
        end;
      end;
    end;
    {$ENDIF}
    
    // (Implement corresponding branches for MacOS kqueue and generic select equivalents...)
  end;
end;

procedure TIdlyEngine.CloseConnection(Connection: TIdlyConnection);
begin
  {$IFDEF LINUX}epoll_ctl(FEpollFD, EPOLL_CTL_DEL, Connection^.FD, nil);{$ENDIF}
  fpClose(Connection.FD);
  FActiveConnections.Remove(Connection);
  Connection.Free;
end;

procedure TIdlyEngine.Stop; begin FRunning := False; end;
constructor TIdlyEngine.Create; begin FActiveConnections := TFPList.Create; FRunning := False; {$IFDEF LINUX}FEpollFD := epoll_create(1);{$ENDIF} end;
destructor TIdlyEngine.Destroy; begin FActiveConnections.Free; inherited Destroy; end;

end.
