unit Main;

interface

uses
  Windows, System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Threading, Messages, IniFiles, ShlObj, ActiveX, ComObj, ShellAPI,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Media,
  FMX.Platform,
  FMX.MultiView,
  FMX.ListView.Types,
  FMX.ListView,
  FMX.Layouts,
  FMX.ActnList,
  FMX.TabControl,
  FMX.ListBox,
  FMX.Controls.Presentation,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.Controls3D,
  FMX.Platform.Win,
  ZXing.BarcodeFormat,
  ZXing.ReadResult,
  ZXing.ScanManager, System.ImageList, FMX.ImgList, FMX.Ani, System.Actions,
  FMX.ExtCtrls;

type
  TForm1 = class(TForm)
    ImgCamera: TImageControl;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    QRMemo: TMemo;
    CameraComponent1: TCameraComponent;
    lblScanStatus: TLabel;
    Panel2: TPanel;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    ActionList1: TActionList;
    Options: TAction;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    SpeedButton1: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure CameraComponent1SampleBufferReady(Sender: TObject;
      const ATime: TMediaTime);
    procedure Button2Click(Sender: TObject);
    procedure OptionsExecute(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure CheckBox2Change(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
  private
    { Private declarations }
  public
    FScanManager: TScanManager;
    FScanInProgress: Boolean;
    FFrameTake: Integer;
    FConfig: TMemIniFile;
    procedure GetImage();
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    function GetConfigFile: TMemIniFile;
    procedure Reg(Write: Boolean);
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure CreateShotCut(SourceFile, ShortCutName, SourceParams: String);
var
IUnk: IUnknown;
ShellLink: IShellLink;
ShellFile: IPersistFile;
tmpShortCutName: string;
WideStr: WideString;
i: Integer;
begin
IUnk := CreateComObject(CLSID_ShellLink);
ShellLink := IUnk as IShellLink;
ShellFile  := IUnk as IPersistFile;
ShellLink.SetPath(PChar(SourceFile));
ShellLink.SetArguments(PChar(SourceParams));
ShellLink.SetWorkingDirectory(PChar(ExtractFilePath(SourceFile)));
ShortCutName := ChangeFileExt(ShortCutName,'.lnk');
if fileexists(ShortCutName) then
begin
ShortCutName := copy(ShortCutName,1,length(ShortCutName)-4);
WideStr := tmpShortCutName;
end
else
WideStr := ShortCutName;
ShellFile.Save(PWChar(WideStr),False);
end;

procedure Startup(Create: Boolean);
var
WorkTable:String;
Find:_WIN32_FIND_DATAA;
P:PItemIDList;
C:array [0..1000] of char;
begin
if SHGetSpecialFolderLocation(0,CSIDL_STARTUP,p)=NOERROR then
begin
SHGetPathFromIDList(P,C);
WorkTable:=StrPas(C);
end;
if Create then
CreateShotCut(ParamStr(0), WorkTable+'\'+ExtractFileName(ChangeFileExt(ParamStr(0),'')), '')
else DeleteFile(WorkTable+'\'+ExtractFileName(ChangeFileExt(ParamStr(0),'.lnk')));
end;

function StartExist: Boolean;
var
WorkTable:String;
Find:_WIN32_FIND_DATAA;
P:PItemIDList;
C:array [0..1000] of char;
begin
if SHGetSpecialFolderLocation(0,CSIDL_STARTUP,p)=NOERROR then
begin
SHGetPathFromIDList(P,C);
WorkTable:=StrPas(C);
end;
if FileExists(WorkTable+'\'+ExtractFileName(ChangeFileExt(ParamStr(0),'.lnk'))) then
Result := True else Result := False;
end;

procedure TForm1.GetImage;
var
  scanBitmap: TBitmap;
  ReadResult: TReadResult;
begin
  CameraComponent1.SampleBufferToBitmap(imgCamera.Bitmap, True);
  if (FScanInProgress) then
  begin
    exit;
  end;
  inc(FFrameTake);
  if (FFrameTake mod 4 <> 0) then
  begin
    exit;
  end;
  scanBitmap := TBitmap.Create();
  scanBitmap.Assign(imgCamera.Bitmap);
  ReadResult := nil;
  TTask.Run(
    procedure
    begin
      try
        FScanInProgress := True;
        try
          ReadResult := FScanManager.Scan(scanBitmap);
        except
          on E: Exception do
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                lblScanStatus.Text := E.Message;
              end);
            exit;
          end;
        end;
        TThread.Synchronize(nil,
          procedure
          begin
            if (length(lblScanStatus.Text) > 10) then
            begin
              lblScanStatus.Text := '*';
            end;
            lblScanStatus.Text := lblScanStatus.Text + '*';
            if (ReadResult <> nil) then
            begin
              QRMemo.Lines.Insert(0, ReadResult.Text);
              Button2Click(Self);
            end;
          end);
      finally
        ReadResult.Free;
        scanBitmap.Free;
        FScanInProgress := false;
      end;
    end);
end;

procedure TForm1.OptionsExecute(Sender: TObject);
begin
Panel2.Visible := not Panel2.Visible;
end;

function TForm1.GetConfigFile: TMemIniFile;
begin
  if FConfig = nil then
  FConfig := TMemIniFile.Create(ExtractFilePath(ParamStr(0))+ExtractFileName(ChangeFileExt(ParamStr(0),'.ini')),TEncoding.UTF8);
  Result := FConfig;
end;

procedure TForm1.Reg(Write: Boolean);
begin
if Write = true then
 begin
   FConfig.WriteInteger('Main','Top',Top);
   FConfig.WriteInteger('Main','Left',Left);
   FConfig.WriteBool('Main','Buf', CheckBox1.IsChecked);
   FConfig.WriteBool('Main','WindowState',CheckBox3.IsChecked);
   FConfig.WriteBool('Main','SendText',CheckBox4.IsChecked);
   FConfig.WriteBool('Main','StayOnTop',CheckBox5.IsChecked);
   FConfig.UpdateFile;
 end else
 begin
   Top := FConfig.ReadInteger('Main','Top',Top);
   Left := FConfig.ReadInteger('Main','Left',Left);
   if FConfig.ReadBool('Main','Buf',False) then
    begin
     CheckBox1.IsChecked := True;
     CheckBox4.Enabled := True;
    end;
   if FConfig.ReadBool('Main','SendText',False) then CheckBox4.IsChecked := True;
   if FConfig.ReadBool('Main','StayOnTop',False) then CheckBox5.IsChecked := True;
   CheckBox2.IsChecked := StartExist;
 end;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
Panel2.Visible := False;
end;

function TForm1.AppEvent(AAppEvent: TApplicationEvent;
AContext: TObject): Boolean;
begin
  case AAppEvent of
    TApplicationEvent.WillBecomeInactive, TApplicationEvent.EnteredBackground,
      TApplicationEvent.WillTerminate:
      CameraComponent1.Active := false;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
if CheckBox5.IsChecked then
SetWindowPos(FormToHWND(Self), HWND_TOPMOST, 0, 0, 0, 0, SWP_NoMove or SWP_NoSize);
CameraComponent1.Active := false;
CameraComponent1.Kind := FMX.Media.TCameraKind.BackCamera;
CameraComponent1.FocusMode := FMX.Media.TFocusMode.ContinuousAutoFocus;
CameraComponent1.Active := True;
lblScanStatus.Text := '';
QRMemo.Lines.Clear;
Options.Enabled := False;
Button1.Enabled := False;
Button2.Enabled := True;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
if CheckBox1.IsChecked then
  begin
    QRMemo.SelectAll;
    QRMemo.CopyToClipboard;
  end;
if (CheckBox4.Enabled = True) and (CheckBox4.IsChecked = True) then
  begin
    keybd_event(VK_CONTROL, 0, 0, 0);
    keybd_event(Ord('V'), 0, 0, 0);
    keybd_event(Ord('V'), 0, KEYEVENTF_KEYUP, 0);
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  end;
CameraComponent1.Active := false;
ImgCamera.Bitmap := nil;
lblScanStatus.Text := '';
Options.Enabled := True;
Button1.Enabled := True;
Button2.Enabled := False;
if CheckBox5.IsChecked then
SetWindowPos(FormToHWND(Self), HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NoMove or SWP_NoSize);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
Panel2.Visible := False;
end;

procedure TForm1.CameraComponent1SampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
TThread.Synchronize(TThread.CurrentThread, GetImage);
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
with Sender as TCheckBox do CheckBox4.Enabled := isChecked;
end;

procedure TForm1.CheckBox2Change(Sender: TObject);
begin
with Sender as TCheckBox do Startup(CheckBox2.IsChecked);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  AppEventSvc: IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService
    (IFMXApplicationEventService, IInterface(AppEventSvc)) then
  begin
    AppEventSvc.SetApplicationEventHandler(AppEvent);
  end;
  lblScanStatus.Text := '';
  FFrameTake := 0;
  CameraComponent1.Quality := FMX.Media.TVideoCaptureQuality.HighQuality;
  lblScanStatus.Text := '';
  FScanManager := TScanManager.Create(TBarcodeFormat.Auto, nil);

  GetConfigFile;
  Reg(False);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
if CameraComponent1.Active then Button2Click(Self);
FScanManager.Free;
Reg(True);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
if FConfig.ReadBool('Main','WindowState',False) then
  begin
    CheckBox3.IsChecked := True;
    ShowWindow(FormToHWND(Self), SW_MINIMIZE);
  end;
end;

end.
