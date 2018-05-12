unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, MMSystem, StdCtrls, DirectSound;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

  private
    { Private declarations }

  public
    { Public declarations }
    procedure TonePlay;
    procedure ToneStop;
  end;

  TPortListner = class(TThread)
    private
    { Private declarations }
    protected
      procedure Execute; override;
  end;

var
  Form1: TForm1;
  PortListner: TPortListner;

implementation

procedure TPortListner.Execute;
var
  hPort: THandle;
  lpEvtMask, lpModemStat: DWORD;
begin
  hPort:= CreateFile(PChar('COM6'),
                        GENERIC_READ or GENERIC_WRITE, 0, nil,
                        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, LongInt(0));

  lpEvtMask := EV_DSR;
  SetCommMask(hPort,lpEvtMask);	// address of variable to get event mask

  while true do
    begin
      WaitCommEvent(hPort, lpEvtMask, nil);
      GetCommModemStatus(hPort,lpModemStat);
      if lpModemStat and MS_DSR_ON <> 0 then
        //SoundMaker.Play(600, 60) // 600 - частота в герцах, 60 - громкость 0-127
        //ShowMessage('play')
        Form1.TonePlay
      else
        //SoundMaker.Stop;
        Form1.ToneStop
        //ShowMessage('stop')
    end;
end;

type
  Int16 = SmallInt;

const Pi = 3.14159265359;
      BitsPerSample = 16;
      SamplesPerSec = 44100;
      //MaxVol = 32767;
      MaxVol = 32767;
var
  DS: IDirectSound;
  DSBuffer: IDirectSoundBuffer;
  BufferSize: LongInt;
  wfx: tWAVEFORMATEX;

{$R *.dfm}

function InitiateDirectSound(hDlg: HWND): Boolean;
var
  DSBPrimary: IDirectSoundBuffer;
  DSBD: TDSBufferDesc;
begin
  DirectSoundCreate(nil, DS, nil);
  DS.SetCooperativeLevel(hDlg, DSSCL_PRIORITY);

  FillChar(DSBD, sizeof(TDSBufferDesc), 0);
  DSBD.dwSize := sizeof(TDSBufferDesc);
  DSBD.dwFlags := DSBCAPS_PRIMARYBUFFER;

  DS.CreateSoundBuffer(DSBD, DSBPrimary, nil);

  FillChar(wfx, sizeof(tWAVEFORMATEX), 0);
  with wfx do
  begin
    wFormatTag := WAVE_FORMAT_PCM;
    nChannels := 1;
    nSamplesPerSec := SamplesPerSec;
    wBitsPerSample := BitsPerSample;
    nBlockAlign := (wBitsPerSample shr 3) * nChannels; // = wBitsPerSample * nChannels / 8;
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
  end;

  DSBPrimary.SetFormat(@wfx);

  if Assigned(DSBPrimary) then DSBPrimary := nil;

  Result := True;
end;

procedure FreeDirectSound;
begin
  if Assigned(DSBuffer) then DSBuffer := nil;
  if Assigned(DS) then DS := nil;
end;

procedure CreateStaticBuffer(hDlg: HWND);
var
  DSBD: TDSBufferDesc;
begin
  if Assigned(DSBuffer) then DSBuffer := nil;

  FillChar(DSBD, sizeof(TDSBufferDesc), 0);
  DSBD.dwSize := sizeof(TDSBufferDesc);
  DSBD.dwFlags := DSBCAPS_STATIC or DSBCAPS_GLOBALFOCUS;
  DSBD.dwBufferBytes := SamplesPerSec * 1; // 1 - 1 сек
  DSBD.lpwfxFormat := @wfx;

  DS.CreateSoundBuffer(DSBD, DSBuffer, nil);

  BufferSize := DSBD.dwBufferBytes;
end;

procedure FillBuffer(Frequency: Word);
var
  bufferBytes: array [0..SamplesPerSec - 1] of Int16;
  AudioPtr1: Pointer;
  lockedSize: DWORD;
  i: Integer;
  pos, r, value: Double;
begin
  //Запираем буфер
  DSBuffer.Lock(0, BufferSize, @AudioPtr1, @lockedSize, nil, nil, 0);

  for i := 0 to lockedSize - 1 do
    begin
      //Определяем цикл, в котором находимся
      pos := Frequency / SamplesPerSec * i;
      //Берём остаток и переводим в радианы
      r := (pos - Int(pos)) * 2 * Pi;
      value := sin(r);

      bufferBytes[i] := Round(value * MaxVol);
    end;
  CopyMemory(AudioPtr1, @bufferBytes, lockedSize);
  //Отпираем буфер
  DSBuffer.Unlock(AudioPtr1, lockedSize, nil, 0);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  InitiateDirectSound(Handle);
  CreateStaticBuffer(Handle);
  FillBuffer(600);
  PortListner:= TPortListner.Create(True);
  PortListner.FreeOnTerminate:=true;
  PortListner.Priority:=tpLower;
  PortListner.Resume;
end;

procedure TForm1.TonePlay;
begin
//  CreateStaticBuffer(Handle);
//  FillBuffer(1440);
  DSBuffer.Play(0, 0, DSBPLAY_LOOPING)
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
//  CreateStaticBuffer(Handle);
//  FillBuffer(1440);
//  DSBuffer.Play(0, 0, DSBPLAY_LOOPING);
  TonePlay
end;

procedure TForm1.ToneStop;
begin
  DSBuffer.Stop()
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  //DSBuffer.Stop();
  ToneStop
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeDirectSound;
end;

end.



