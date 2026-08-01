program idly_pkt_test;

{$mode objfpc}{$H+}

uses
  SysUtils, idly_pkt;

var
  PktHeader: TPKTHeader;
  NewMail: TFTNMessage;
  DT: TDateTime;
  Year, Month, Day, Hour, Min, Sec, MSec: Word;

begin
  // 1. Process incoming packet from outbound BinkP nodes safely
  Writeln('Tossing inbound packet...');
  TIdlyPKTEngine.ReadPacket('/home/user/idly/inbound/00000000.pkt');

  // 2. Generate outbound mail packet
  Writeln('Creating outbound packet configuration structure...');
  DT := Now;
  DecodeDate(DT, Year, Month, Day);
  DecodeTime(DT, Hour, Min, Sec, MSec);

  FillChar(PktHeader, SizeOf(TPKTHeader), 0);
  PktHeader.OrigNode := 999;
  PktHeader.DestNode := 100;
  PktHeader.OrigNet  := 3603;
  PktHeader.DestNet  := 3603;
  PktHeader.OrigZone := 1;
  PktHeader.DestZone := 1;
  PktHeader.PktType  := 2;
  PktHeader.Year     := Year;
  PktHeader.Month    := Month - 1; // Adjust to Fido 0-11 mapping parameters
  PktHeader.Day      := Day;
  PktHeader.Hour     := Hour;
  PktHeader.Minute   := Min;
  PktHeader.Second   := Sec;
  PktHeader.Password := 'SECRET';

  NewMail.OrigZone := 1; NewMail.OrigNet := 3603; NewMail.OrigNode := 999; NewMail.OrigPoint := 0;
  NewMail.DestZone := 1; NewMail.DestNet := 3603; NewMail.DestNode := 100; NewMail.DestPoint := 0;
  NewMail.DateTimeStr := '01 Aug 26  16:45:00'; // Match standard spacing rules
  NewMail.FromUser := 'Ozz Nixon';
  NewMail.ToUser   := 'SysOp Node';
  NewMail.Subject  := 'Automated Idly Test Packet';
  NewMail.Text     := 'Hello from your Debian desktop environment build suite!'#13;

  TIdlyPKTEngine.CreatePacket('/home/user/idly/outbound/13603999.pkt', PktHeader, NewMail);
  Writeln('Outbound packet built.');
end.
