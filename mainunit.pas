unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazFileUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, Menus, ActnList, StdActns, Process,
  {$IFDEF DARWIN}MacOSAll, CarbonProc,{$ENDIF}
  StrUtils;

type

  { TMainForm }

  TMainForm = class(TForm)
    ActionList1: TActionList;
    GoButton: TButton;
    FileOpen1: TFileOpen;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    Memo2: TMemo;
    MenuItem2: TMenuItem;
    MenuItem1: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    Panel1: TPanel;
    Shape1: TShape;
    procedure GoButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure Image1Click(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;


const
  debug: boolean = false;
  goodFOURCC: array[0..3] of char = ('d','v','s','d');  // Standard DV
  badFOURCC: array[0..3] of char = ('c','d','v','c');   // Canopus DV

var
  MainForm: TMainForm;
  ResourcesDir, AppSuppDir, ffmpeg_p: String;
  fajlovi: array of String;
  fsTempFajl: TFileStream;

implementation

{$R *.lfm}

function fInstalirajFFmpeg(ImeFFmpega: string): boolean;
{$IFDEF UNIX}
var
    installproc: TProcess;
{$ENDIF}
begin
  result := false;
  if not FileExists(ffmpeg_p) then result := CopyFile(ImeFFmpega, ffmpeg_p)
  else
    if MessageDlg('Pitanje', 'ffmpeg vec postoji! Da li da nastavim?', mtConfirmation, [mbYes, mbNo],0) = mrYes  then result := CopyFile(ImeFFmpega, ffmpeg_p);
  {$IFDEF UNIX}
    installproc:=TProcess.Create(nil);
    installproc.Executable:='/bin/chmod';
    installproc.Parameters.Add('755');
    installproc.Parameters.Add(ffmpeg_p);
    installproc.Execute;
    installproc.Free;
  {$ENDIF}
  if FileExists(ffmpeg_p) and result = true then
    ShowMessage('Instalacija ffmpeg-a uspela!')
  else
    ShowMessage('Instalacija ffmpeg-a neuspesna!');
end;

function fFixCanopus(ImeAVIja: string): integer;  // return 0 - OK, 1 - Nije primenljivo, 2 - greska
var
  fsFajl : TFileStream;
  tempFOURCC: array [0..3] of char;
begin
  result := 2;
  tempFOURCC := ('0000');
      try
        fsFajl := TFileStream.Create( ImeAVIja, fmOpenReadWrite);
        fsFajl.Seek(112, soFromBeginning);    // idi na dec offset za hex 70
        fsFajl.ReadBuffer(tempFOURCC, 4);     // posle ovoga mora da se ponovi pozicioniranje
        if tempFOURCC = badFOURCC then
          begin
            fsFajl.Seek(112, soFromBeginning);    // ponovo idi na dec offset za hex 70
            fsFajl.WriteBuffer(goodFOURCC, 4);
            fsFajl.Seek(188, soFromBeginning);    // idi na dec offset za hex BC
            fsFajl.WriteBuffer(goodFOURCC, 4);
            fsFajl.Free;
            result := 0;
          end
        else
          begin
            fsFajl.Free;
            result := 1;
          end;
      except
        on E:Exception do
        begin
          result := 2;
          ShowMessage('Doslo je do greske prilikom obrade: ' + ImeAVIja + ' Nije obradjen zbog: ' + E.Message);
        end;
      end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainForm.Caption := Application.Title;
  {$IFDEF DARWIN}
  MenuItem1.Caption := #$EF#$A3#$BF;  //Unicode Apple logo char
  ResourcesDir := ExtractFileDir(ExtractFileDir(Application.ExeName)+'/Resources');
  AppSuppDir := TrimFilename(GetUserDir+PathDelim+'Library/Application Support'+PathDelim+Application.Title+PathDelim);
  ffmpeg_p := TrimFilename(AppSuppDir+PathDelim+'ffmpeg');
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  ResourcesDir := ExtractFileDir(ExtractFileDir(Application.ExeName)+'/Resources');
  AppSuppDir := TrimFilename(GetAppConfigDir(FALSE)+PathDelim);
  ffmpeg_p := TrimFilename(AppSuppDir+PathDelim+'ffmpeg.exe');
  {$ENDIF}

  if not DirectoryExistsUTF8(AppSuppDir) then if not CreateDir(AppSuppDir) then ShowMessage('Direktorijum: ' + AppSuppDir + ' nije napravljen!');
  if not FileExistsUTF8(ffmpeg_p) then ShowMessage('ffmpeg nije instaliran! Ispusti ffmpeg na glavni prozor programa za automatsku instalaciju.');

  if debug then ShowMessage('App Support Dir: ' + AppSuppDir + sLineBreak + 'FFMpeg exe: ' + ffmpeg_p);
end;

procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of String);
var
  i, br: integer;
  tempListaFajlova : array of String;
begin
  SetLength(fajlovi,Length(FileNames));
  Memo1.Visible := true;
  Memo1.Align := alClient;
  Memo1.Clear;
  Memo2.Visible := false;
  for i:=0 to Length(FileNames) - 1 do
    begin
      fajlovi[i] := FileNames[i];
       Memo1.Append(fajlovi[i]);
    end;
  br := 1;
  while Memo1.Lines.Count > 0 do
    begin
      {$IFDEF UNIX}
      if sysutils.CompareText(ExtractFileName(Memo1.Lines.Strings[0]), 'ffmpeg') = 0 then
      {$ENDIF}
      {$IFDEF MSWINDOWS}
      if sysutils.CompareText(ExtractFileName(Memo1.Lines.Strings[0]), 'ffmpeg.exe') = 0 then
      {$ENDIF}
      begin
        fInstalirajFFmpeg(Memo1.Lines.Strings[0]);
        Memo1.Lines.Delete(0);
      end
      else
        if sysutils.CompareText(ExtractFileExt(Memo1.Lines.Strings[0]), '.avi') = 0 then
        begin
          if fFixCanopus(Memo1.Lines.Strings[0]) = 1 then
          begin
            SetLength(tempListaFajlova, br);
            tempListaFajlova[br-1] := Memo1.Lines.Strings[0];
            br := br+1;
            Memo1.Lines.Delete(0);
          end;
        end
      else
        if sysutils.CompareText(ExtractFileExt(Memo1.Lines.Strings[0]), '.mov') = 0 then
        begin
          // operacije sa movom
          SetLength(tempListaFajlova, br);
          tempListaFajlova[br-1] := Memo1.Lines.Strings[0];
          br := br+1;
          Memo1.Lines.Delete(0);
        end;
    end;
  if Length(tempListaFajlova) > 0 then
  begin
    setLength(fajlovi, Length(tempListaFajlova));
    for i := 0 to Length(tempListaFajlova) -1 do
      begin
        fajlovi[i] := tempListaFajlova[i];
        Memo1.Lines.Add(tempListaFajlova[i])
      end;
    GoButton.Enabled:=true;
  end
  else
    Memo1.Visible := false;
end;

procedure TMainForm.Image1Click(Sender: TObject);
begin

end;

procedure TMainForm.GoButtonClick(Sender: TObject);
var
  i: integer;
  ffproc_mov_u_avi: TProcess;
  AStringList: TStringList;
  NovoIme: string;
begin
  for i:=0 to Length(fajlovi) - 1 do
    begin
      ffproc_mov_u_avi := TProcess.Create(nil);
      ffproc_mov_u_avi.Options := ffproc_mov_u_avi.Options + [poUsePipes];
      ffproc_mov_u_avi.Executable := ffmpeg_p;
      try
        fsTempFajl := TFileStream.Create(GetTempFileNameUTF8(GetTempDir(false),'dFFmpegTemp_'), fmCreate);
      except
        on E: Exception do
          MessageDlg('GRESKA!', 'Doslo je do greske prilikom generisanja privremenog fajla za konverziju!', mtError, [mbOK], 0);
      end;
      Memo2.Lines.Clear;
//      Memo2.Visible := true;
      NovoIme := ChangeFileExt(fajlovi[i], '.avi');
      while  FileExists(NovoIme) do
        NovoIme := ChangeFileExt(NovoIme, '_1.avi');
      with ffproc_mov_u_avi do
      try
        Parameters.Add('-progress');
        Parameters.Add(fsTempFajl.FileName);
        Parameters.Add('-i');
        Parameters.Add(fajlovi[i]);
        Parameters.Add('-vcodec');
        Parameters.Add('copy');
        Parameters.Add('-acodec');
        Parameters.Add('copy');
        //-async 1 -aspect 4:3 -c:d copy -threads 4
        Parameters.Add('-sn');
        Parameters.Add('-y');
        Parameters.Add(NovoIme);

        Execute;

        AStringList := TStringList.Create;
        AStringList.LoadFromStream(ffproc_mov_u_avi.Output);
        AStringList.Add('Komanda za izvrsenje:');
        AStringList.Add(ffproc_mov_u_avi.Executable);
        AStringList.AddStrings(ffproc_mov_u_avi.Parameters);
        while Active or Running do
          begin
            Memo2.Lines.LoadFromStream(fsTempFajl);
          end;
      finally
        Free
      end;
      if not DeleteFile(fsTempFajl.FileName) then MessageDlg('GRESKA!', 'Doslo je do greske prilikom ciscenja privremenih fajlova posle konverzije', mtError, [mbOK], 0);
      AStringList.Free;
      fsTempFajl.Free;
      Memo1.Lines.Delete(0);
    end;
  GoButton.Enabled:=False;
end;

end.


