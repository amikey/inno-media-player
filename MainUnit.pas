unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Forms, ActiveX, DirectShow9;

const
  WM_GRAPH_NOTIFY = WM_USER + 1;

type
  EDirectShowPlayerException = class(Exception)
  private
    FErrorCode: HRESULT;
  public
    constructor Create(ErrorCode: HRESULT);
    property ErrorCode: HRESULT read FErrorCode;
  end;
  TDirectShowEventProc = procedure(EventCode, Param1, Param2: Integer) of object;
  TDirectShowPlayerState = (
    dspsUninitialized,
    dspsInitialized,
    dspsPlaying,
    dspsPaused
  );
  TDirectShowPlayer = class
  strict private
    FLastError: HRESULT;
    FWindowHandle: HWND;
    FPlayerState: TDirectShowPlayerState;
    FEventCallback: TDirectShowEventProc;
    FBasicAudio: IBasicAudio;
    FVideoWindow: IVideoWindow;
    FGraphBuilder: IGraphBuilder;
    FMediaEventEx: IMediaEventEx;
    FMediaControl: IMediaControl;
    procedure HandleEvents;
    function ErrorCheck(Value: HRESULT): HRESULT;
    procedure InitializeMediaPlay(FileName: PWideChar);
    procedure FinalizeMediaPlay;
    procedure InitializeFilterGraph;
    procedure FinalizeFilterGraph;
    procedure InitializeVideoWindow(WindowHandle: HWND; var Width, Height: Integer);
    procedure FinalizeVideoWindow;
    procedure WndProc(var AMessage: TMessage);
  public
    constructor Create;
    destructor Destroy; override;
    function InitializeAudioFile(FileName: PWideChar;
      CallbackProc: TDirectShowEventProc): HRESULT;
    function InitializeVideoFile(FileName: PWideChar; WindowHandle: HWND;
      var Width, Height: Integer; CallbackProc: TDirectShowEventProc): HRESULT;
    function PlayMediaFile: HRESULT;
    function StopMediaPlay: HRESULT;
    function PauseMediaPlay: HRESULT;
    function SetVolume(Value: LongInt): HRESULT;
    function SetBalance(Value: LongInt): HRESULT;
    property LastError: HRESULT read FLastError;
  end;

function DSGetLastError(var ErrorText: PWideChar): HRESULT; stdcall;
function DSInitializeAudioFile(FileName: PWideChar; CallbackProc: TDirectShowEventProc):
  Boolean; stdcall;
function DSInitializeVideoFile(const FileName: PWideChar; WindowHandle: HWND; var Width,
  Height: Integer; CallbackProc: TDirectShowEventProc): Boolean; stdcall;
function DSPlayMediaFile: Boolean; stdcall;
function DSStopMediaPlay: Boolean; stdcall;
function DSPauseMediaPlay: Boolean; stdcall;
function DSSetVolume(Value: LongInt): Boolean; stdcall;
function DSSetBalance(Value: LongInt): Boolean; stdcall;

var
  DirectShowPlayer: TDirectShowPlayer;

implementation

{ EDirectShowPlayerException }

constructor EDirectShowPlayerException.Create(ErrorCode: HRESULT);
begin
  FErrorCode := ErrorCode;
  inherited Create('');
end;

{ TDirectShowPlayer }

constructor TDirectShowPlayer.Create;
begin
  inherited Create;
  FPlayerState := dspsUninitialized;
  FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TDirectShowPlayer.Destroy;
begin
  StopMediaPlay;
  DeallocateHWnd(FWindowHandle);
  inherited;
end;

function TDirectShowPlayer.ErrorCheck(Value: HRESULT): HRESULT;
var
  DirectShowPlayerException: EDirectShowPlayerException;
begin
  Result := Value;
  FLastError := Value;
  if Failed(Value) then
  begin
    DirectShowPlayerException := EDirectShowPlayerException.Create(Value);
    raise DirectShowPlayerException;
  end;
end;

procedure TDirectShowPlayer.InitializeMediaPlay(FileName: PWideChar);
begin
  ErrorCheck(FGraphBuilder.RenderFile(FileName, nil));
end;

procedure TDirectShowPlayer.FinalizeMediaPlay;
begin
  if Assigned(FMediaControl) then
    ErrorCheck(FMediaControl.Stop);
end;

procedure TDirectShowPlayer.InitializeFilterGraph;
begin
  ErrorCheck(CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
    IID_IFilterGraph2, FGraphBuilder));
  ErrorCheck(FGraphBuilder.QueryInterface(IBasicAudio, FBasicAudio));
  ErrorCheck(FGraphBuilder.QueryInterface(IMediaControl, FMediaControl));
  ErrorCheck(FGraphBuilder.QueryInterface(IMediaEventEx, FMediaEventEx));
  ErrorCheck(FMediaEventEx.SetNotifyFlags(0));
  ErrorCheck(FMediaEventEx.SetNotifyWindow(FWindowHandle, WM_GRAPH_NOTIFY,
    ULONG(FMediaEventEx)));
  FPlayerState := dspsInitialized;
end;

procedure TDirectShowPlayer.FinalizeFilterGraph;
begin
  FBasicAudio := nil;
  FMediaEventEx := nil;
  FMediaControl := nil;
  FGraphBuilder := nil;
  FPlayerState := dspsUninitialized;
end;

procedure TDirectShowPlayer.InitializeVideoWindow(WindowHandle: HWND; var Width,
  Height: Integer);
begin
  ErrorCheck(FGraphBuilder.QueryInterface(IVideoWindow, FVideoWindow));
  ErrorCheck(FVideoWindow.put_Owner(WindowHandle));
  ErrorCheck(FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS));
  ErrorCheck(FVideoWindow.put_Left(0));
  ErrorCheck(FVideoWindow.put_Top(0));
  if (Width = 0) or (Height = 0) then
  begin
    FVideoWindow.get_Width(Width);
    FVideoWindow.get_Height(Height);
  end
  else
  begin
    FVideoWindow.put_Width(Width);
    FVideoWindow.put_Height(Height);
  end;
end;

procedure TDirectShowPlayer.FinalizeVideoWindow;
begin
  if Assigned(FVideoWindow) then
  begin
    ErrorCheck(FVideoWindow.put_Visible(False));
    ErrorCheck(FVideoWindow.put_Owner(0));
    FVideoWindow := nil;
  end;
end;

function TDirectShowPlayer.InitializeAudioFile(FileName: PWideChar;
  CallbackProc: TDirectShowEventProc): HRESULT;
begin
  Result := S_FALSE;
  try
    FEventCallback := CallbackProc;
    if FPlayerState in [dspsPlaying, dspsPaused] then
      FinalizeMediaPlay;
    if FPlayerState <> dspsUninitialized then
    begin
      FinalizeVideoWindow;
      FinalizeFilterGraph;
    end;
    InitializeFilterGraph;
    InitializeMediaPlay(FileName);
  except
    Result := FLastError;
    FinalizeVideoWindow;
    FinalizeFilterGraph;
  end;
end;

function TDirectShowPlayer.InitializeVideoFile(FileName: PWideChar; WindowHandle: HWND;
  var Width, Height: Integer; CallbackProc: TDirectShowEventProc): HRESULT;
begin
  Result := S_FALSE;
  try
    FEventCallback := CallbackProc;
    if FPlayerState in [dspsPlaying, dspsPaused] then
      FinalizeMediaPlay;
    if FPlayerState <> dspsUninitialized then
    begin
      FinalizeVideoWindow;
      FinalizeFilterGraph;
    end;
    InitializeFilterGraph;
    InitializeMediaPlay(FileName);
    InitializeVideoWindow(WindowHandle, Width, Height);
  except
    Result := FLastError;
    FinalizeVideoWindow;
    FinalizeFilterGraph;
  end;
end;

function TDirectShowPlayer.PlayMediaFile: HRESULT;
begin
  Result := S_FALSE;
  try
    if FPlayerState = dspsInitialized then
      Result := ErrorCheck(FMediaControl.Run);
    FPlayerState := dspsPlaying;
  except
    Result := FLastError;
  end;
end;

function TDirectShowPlayer.StopMediaPlay: HRESULT;
begin
  Result := S_FALSE;
  try
    if FPlayerState in [dspsPlaying, dspsPaused] then
      FinalizeMediaPlay;
    if FPlayerState <> dspsUninitialized then
    begin
      FinalizeVideoWindow;
      FinalizeFilterGraph;
    end;
  except
    Result := FLastError;
  end;
end;

function TDirectShowPlayer.PauseMediaPlay: HRESULT;
begin
  Result := S_FALSE;
  try
    if FPlayerState = dspsInitialized then
      Result := ErrorCheck(FMediaControl.Pause);
    FPlayerState := dspsPaused;
  except
    Result := FLastError;
  end;
end;

function TDirectShowPlayer.SetVolume(Value: LongInt): HRESULT;
begin
  try
    Result := ErrorCheck(FBasicAudio.put_Volume(Value));
  except
    Result := FLastError;
  end;
end;

function TDirectShowPlayer.SetBalance(Value: LongInt): HRESULT;
begin
  try
    Result := ErrorCheck(FBasicAudio.put_Balance(Value));
  except
    Result := FLastError;
  end;
end;

procedure TDirectShowPlayer.WndProc(var AMessage: TMessage);
begin
  if AMessage.Msg = WM_GRAPH_NOTIFY then
    try
      HandleEvents;
    except
      Application.HandleException(Self);
    end
  else
    AMessage.Result := DefWindowProc(FWindowHandle, AMessage.Msg, AMessage.WParam,
      AMessage.LParam);
end;

procedure TDirectShowPlayer.HandleEvents;
var
  EventCode, Param1, Param2: Integer;
begin
  if Assigned(FMediaEventEx) then
  begin
    while Succeeded(FMediaEventEx.GetEvent(EventCode, Param1, Param2, 0)) do
    begin
      FEventCallback(EventCode, Param1, Param2);
      FMediaEventEx.FreeEventParams(EventCode, Param1, Param2);
    end;
  end;
end;

function DSGetLastError(var ErrorText: PWideChar): HRESULT;
begin
  Result := DirectShowPlayer.LastError;
  AMGetErrorText(Result, ErrorText, 256);
end;

function DSInitializeAudioFile(FileName: PWideChar; CallbackProc: TDirectShowEventProc):
  Boolean;
begin
  Result := Succeeded(DirectShowPlayer.InitializeAudioFile(FileName, CallbackProc));
end;

function DSInitializeVideoFile(const FileName: PWideChar; WindowHandle: HWND;
  var Width, Height: Integer; CallbackProc: TDirectShowEventProc): Boolean;
begin
  Result := Succeeded(DirectShowPlayer.InitializeVideoFile(FileName, WindowHandle,
    Width, Height, CallbackProc));
end;

function DSPlayMediaFile: Boolean;
begin
  Result := Succeeded(DirectShowPlayer.PlayMediaFile);
end;

function DSStopMediaPlay: Boolean;
begin
  Result := Succeeded(DirectShowPlayer.StopMediaPlay);
end;

function DSPauseMediaPlay: Boolean;
begin
  Result := Succeeded(DirectShowPlayer.PauseMediaPlay);
end;

function DSSetVolume(Value: LongInt): Boolean;
begin
  Result := Succeeded(DirectShowPlayer.SetVolume(Value));
end;

function DSSetBalance(Value: LongInt): Boolean;
begin
  Result := Succeeded(DirectShowPlayer.SetBalance(Value));
end;

initialization
  DirectShowPlayer := TDirectShowPlayer.Create;
finalization
  DirectShowPlayer.Free;

end.
