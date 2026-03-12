unit XmlDoc.Plugin.QuickDocPreview;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  /// <summary>Help Insight 스타일의 풍선 도움말 미리보기</summary>
  TQuickDocPreview = class
  private
    FHintWindow: THintWindow;
    FVisible: Boolean;

    function RenderCompactHTML(const AModel: TXmlDocModel; const AElement: TCodeElementInfo): string;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>풍선 도움말을 표시합니다.</summary>
    /// <param name="AElement">코드 요소 정보</param>
    /// <param name="AModel">문서 모델</param>
    /// <param name="AScreenPos">스크린 좌표</param>
    procedure ShowPreview(const AElement: TCodeElementInfo; const AModel: TXmlDocModel; AScreenPos: TPoint);

    /// <summary>풍선 도움말을 숨깁니다.</summary>
    procedure HidePreview;

    property Visible: Boolean read FVisible;
  end;

implementation

{ TQuickDocPreview }

constructor TQuickDocPreview.Create;
begin
  inherited Create;
  FHintWindow := THintWindow.Create(nil);
  FHintWindow.Color := $00F5F5DC;
  FVisible := False;
end;

destructor TQuickDocPreview.Destroy;
begin
  FHintWindow.Free;
  inherited;
end;

procedure TQuickDocPreview.ShowPreview(const AElement: TCodeElementInfo; const AModel: TXmlDocModel; AScreenPos: TPoint);
var
  LText: string;
  LRect: TRect;
  LMaxWidth: Integer;
begin
  LText := RenderCompactHTML(AModel, AElement);
  if LText = '' then
  begin
    HidePreview;
    Exit;
  end;

  LMaxWidth := 480;

  // 힌트 표시
  LRect := FHintWindow.CalcHintRect(LMaxWidth, LText, nil);
  OffsetRect(LRect, AScreenPos.X, AScreenPos.Y + 20);

  // 화면 범위 보정
  if LRect.Right > Screen.DesktopWidth then
    OffsetRect(LRect, Screen.DesktopWidth - LRect.Right - 8, 0);
  if LRect.Bottom > Screen.DesktopHeight then
    OffsetRect(LRect, 0, -(LRect.Height + 40));

  FHintWindow.ActivateHint(LRect, LText);
  FVisible := True;
end;

procedure TQuickDocPreview.HidePreview;
begin
  if FVisible then
  begin
    FHintWindow.ReleaseHandle;
    FVisible := False;
  end;
end;

function TQuickDocPreview.RenderCompactHTML(const AModel: TXmlDocModel; const AElement: TCodeElementInfo): string;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    // 시그니처 헤더
    if AElement.FullName <> '' then
    begin
      LSB.Append(AElement.Kind.ToString + ' ');
      LSB.AppendLine(AElement.FullName);
      LSB.AppendLine('────────────────────────');
    end;

    // Summary
    if AModel.Summary <> '' then
      LSB.AppendLine(AModel.Summary)
    else
    begin
      Result := '';
      Exit;
    end;

    // Parameters
    if AModel.Params.Count > 0 then
    begin
      LSB.AppendLine;
      LSB.AppendLine('Parameters:');
      for I := 0 to AModel.Params.Count - 1 do
      begin
        LSB.AppendFormat('  %s', [AModel.Params[I].Name]);
        if AModel.Params[I].Description <> '' then
          LSB.AppendFormat(' — %s', [AModel.Params[I].Description]);
        LSB.AppendLine;
      end;
    end;

    // Returns
    if AModel.Returns <> '' then
    begin
      LSB.AppendLine;
      LSB.AppendLine('Returns: ' + AModel.Returns);
    end;

    // Exceptions
    if AModel.Exceptions.Count > 0 then
    begin
      LSB.AppendLine;
      LSB.AppendLine('Raises:');
      for I := 0 to AModel.Exceptions.Count - 1 do
      begin
        LSB.AppendFormat('  %s', [AModel.Exceptions[I].TypeRef]);
        if AModel.Exceptions[I].Description <> '' then
          LSB.AppendFormat(' — %s', [AModel.Exceptions[I].Description]);
        LSB.AppendLine;
      end;
    end;

    // Remarks (첫 줄만)
    if AModel.Remarks <> '' then
    begin
      LSB.AppendLine;
      if Pos(sLineBreak, AModel.Remarks) > 0 then
        LSB.AppendLine('Remarks: ' + Copy(AModel.Remarks, 1,
          Pos(sLineBreak, AModel.Remarks) - 1) + '...')
      else
        LSB.AppendLine('Remarks: ' + AModel.Remarks);
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

end.
