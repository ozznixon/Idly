program idly_mailer_node;

{$mode objfpc}{$H+}

uses
  idly_core, idly_binkp, idly_legacy_ftn;

var
  Engine: TIdlyEngine;

begin
  Engine := TIdlyEngine.Create;
  try
    // 1. Modern BinkP Mail transfers mapped to port 24554
    Engine.RegisterProtocol(24554, TBinkPProtocolFactory.Create);
    
    // 2. Vintage dial-up emulations (EMS, YooHoo, StoneAge) on alternative port 
    Engine.RegisterProtocol(60179, TLegacyFTNFactory.Create);

    Writeln('Idly Mailer Service Node actively running non-blocking protocols...');
    Engine.Run;
  finally
    Engine.Free;
  end;
end.
