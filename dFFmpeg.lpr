program dFFmpeg;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  {$IFDEF DARWIN}

  {$ENDIF}
  {$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}

  Interfaces, // this includes the LCL widgetset
  Forms, runtimetypeinfocontrols, MainUnit
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

