[Setup]
AppName=Media Player Project
AppVersion=1.0
DefaultDirName={pf}\Media Player Project

[Files]
Source: "MediaPlayer.dll"; Flags: dontcopy
Source: "InnoCallback.dll"; Flags: dontcopy

[Code]
const
  EC_COMPLETE = $01;

type
  TDirectShowEventProc = procedure(EventCode, Param1, Param2: Integer);

function DSGetLastError(var ErrorText: WideString): HRESULT;
  external 'DSGetLastError@files:mediaplayer.dll stdcall';
function DSPlayMediaFile: Boolean;
  external 'DSPlayMediaFile@files:mediaplayer.dll stdcall';
function DSStopMediaPlay: Boolean;
  external 'DSStopMediaPlay@files:mediaplayer.dll stdcall';
function DSInitializeAudioFile(FileName: WideString; CallbackProc: LongWord):
  Boolean; external 'DSInitializeAudioFile@files:mediaplayer.dll stdcall';
function DSInitializeVideoFile(FileName: WideString; WindowHandle: HWND; var Width,
  Height: Integer; CallbackProc: LongWord): Boolean;
  external 'DSInitializeVideoFile@files:mediaplayer.dll stdcall';
function WrapDirectShowEventProc(Callback: TDirectShowEventProc; 
  ParamCount: Integer): LongWord; external 'wrapcallback@files:InnoCallback.dll stdcall';  

var
  VideoForm: TSetupForm;
  AudioPage: TWizardPage;
  VideoPage: TWizardPage;
  VideoPanel: TPanel;

procedure OnMediaPlayerEvent(EventCode, Param1, Param2: Integer); 
begin
  if EventCode = EC_COMPLETE then
    VideoForm.Close;
end;

procedure OnVideoFormShow(Sender: TObject);
var
  ErrorCode: HRESULT;
  ErrorText: WideString; 
  Width, Height: Integer;
  DirectShowEventProc: LongWord;
begin
  DirectShowEventProc := WrapDirectShowEventProc(@OnMediaPlayerEvent, 3);
  if DSInitializeVideoFile('d:\Video.avi', VideoForm.Handle, Width, 
    Height, DirectShowEventProc)
  then
  begin
    VideoForm.ClientWidth := Width;
    VideoForm.ClientHeight := Height;
    DSPlayMediaFile;
  end
  else
  begin
    ErrorCode := DSGetLastError(ErrorText);
    MsgBox('TDirectShowPlayer error: ' + IntToStr(ErrorCode) + '; ' + 
      ErrorText, mbError, MB_OK);
  end;
end;

procedure OnVideoFormClose(Sender: TObject; var Action: TCloseAction);
begin
  DSStopMediaPlay;
end;

procedure InitializeWizard;
begin
  VideoForm := CreateCustomForm;
  VideoForm.Position := poScreenCenter;
  VideoForm.OnShow := @OnVideoFormShow;
  VideoForm.OnClose := @OnVideoFormClose;
  VideoForm.FormStyle := fsStayOnTop;
  VideoForm.Caption := 'Popup Video Window';
  VideoForm.ShowModal;

  VideoPage := CreateCustomPage(wpWelcome, 'Video Page', 'Embedded video');
  VideoPanel := TPanel.Create(WizardForm);
  VideoPanel.Parent := VideoPage.Surface;
  VideoPanel.BevelOuter := bvNone;
  VideoPanel.Width := Round(VideoPage.Surface.ClientWidth / 1.5);
  VideoPanel.Height := Round(VideoPage.Surface.ClientHeight / 1.5);
  VideoPanel.Left := (VideoPage.Surface.ClientWidth - VideoPanel.Width) div 2;
  VideoPanel.Top := (VideoPage.Surface.ClientHeight - VideoPanel.Height) div 2;

  AudioPage := CreateCustomPage(VideoPage.ID, 'Audio Page', 'Embedded audio');
end;

procedure OnEmbeddedMediaPlayerEvent(EventCode, Param1, Param2: Integer); 
begin
  if EventCode = EC_COMPLETE then
    MsgBox('Playback is done!', mbInformation, MB_OK);
end;

procedure CurPageChanged(CurPageID: Integer);
var
  ErrorCode: HRESULT;
  ErrorText: WideString; 
  Width, Height: Integer;
  DirectShowEventProc: LongWord;
begin
  case CurPageID of
    VideoPage.ID:
    begin
      DirectShowEventProc := WrapDirectShowEventProc(@OnEmbeddedMediaPlayerEvent, 3);
      Width := VideoPanel.ClientWidth; 
      Height := VideoPanel.ClientHeight;
      WizardForm.InnerPage.Color := clBlack; 
      if DSInitializeVideoFile('d:\Video.avi', VideoPanel.Handle, Width, Height, 
        DirectShowEventProc)
      then
        DSPlayMediaFile
      else
      begin
        ErrorCode := DSGetLastError(ErrorText);
        MsgBox('TDirectShowPlayer error: ' + IntToStr(ErrorCode) + '; ' + 
          ErrorText, mbError, MB_OK);
      end;
    end;
    AudioPage.ID:
    begin
      WizardForm.InnerPage.Color := clBtnFace;
      DirectShowEventProc := WrapDirectShowEventProc(@OnEmbeddedMediaPlayerEvent, 3);
      if DSInitializeAudioFile('d:\Audio.mp3', DirectShowEventProc) then
        DSPlayMediaFile
      else
      begin
        ErrorCode := DSGetLastError(ErrorText);
        MsgBox('TDirectShowPlayer error: ' + IntToStr(ErrorCode) + '; ' + 
          ErrorText, mbError, MB_OK);
      end;
    end
  else
    begin
      DSStopMediaPlay;
      WizardForm.InnerPage.Color := clBtnFace;
    end;
  end;
end;

procedure DeinitializeSetup;
begin
  DSStopMediaPlay;
end;

