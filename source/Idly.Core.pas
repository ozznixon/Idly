(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*  Filename: Idly.Core.pas                                          *)
(* Copyright: (C) 2026 by Brain Patchwork DX, LLC. build 1260801     *)
(* ================================================================= *)
(* Even though I author DXSock, a commercial socket suite ~ this was *)
(* written to give people access to my talent for free.              *)
(* ozznixon@gmail.com                                                *)
(* Ozz Nixon                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
{Place Holder}
unit Idly.Core;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes, Generics.Collections, Idly.Types;

type
  TIdlyEngine = class
  private
    type
      THandlerMap = TDictionary<Integer, IIdlyProtocolHandler>;
  private
    FHandlers: THandlerMap;
    FIsRunning: Boolean;
    procedure RunEventLoop;
  public
    constructor Create;
    destructor Destroy; override;
    
    { Register an RFC implementation to a specific network port }
    procedure RegisterRFC(APort: Integer; const AHandler: IIdlyProtocolHandler);
    procedure Start;
    procedure Stop;
    
    property IsRunning: Boolean read FIsRunning;
  end;

implementation

constructor TIdlyEngine.Create;
begin
  FHandlers := THandlerMap.Create;
  FIsRunning := False;
end;

destructor TIdlyEngine.Destroy;
begin
  FHandlers.Free;
  inherited Destroy;
end;

procedure TIdlyEngine.RegisterRFC(APort: Integer; const AHandler: IIdlyProtocolHandler);
begin
  if FIsRunning then
    raise Exception.Create('Cannot register RFC handlers while engine is active.');
  FHandlers.AddOrSetValue(APort, AHandler);
end;

procedure TIdlyEngine.Start;
begin
  if FIsRunning then Exit;
  FIsRunning := True;
  RunEventLoop;
end;

procedure TIdlyEngine.Stop;
begin
  FIsRunning := False;
end;

procedure TIdlyEngine.RunEventLoop;
begin
  while FIsRunning do
  begin
    { Low-level non-blocking socket multiplexing logic goes here }
    { (e.g., fpSelect, epoll, or kqueue hooks) See v1.1! }
    
    Sleep(1); // Visual anchor placeholder for the polling slice
  end;
end;

end.
