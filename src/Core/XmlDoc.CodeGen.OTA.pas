unit XmlDoc.CodeGen.OTA;

interface

uses
  System.SysUtils,
  System.Classes,
  ToolsAPI,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.CodeGen;

type
  /// <summary>IOTAEditWriter를 사용해 주석을 소스 에디터에 직접 적용합니다 (Undo 지원).</summary>
  TDocOTAWriter = class
  private
    class function GetEditorPosition(const AEditor: IOTASourceEditor; ALine, ACol: Integer): Integer;
  public
    /// <summary>IOTAEditWriter를 통해 주석 블록을 소스 에디터에 적용합니다.</summary>
    /// <param name="AEditor">대상 소스 에디터</param>
    /// <param name="AElement">대상 코드 요소 정보</param>
    /// <param name="AModel">적용할 문서 모델</param>
    /// <returns>성공 여부</returns>
    class function ApplyToEditor(const AEditor: IOTASourceEditor; const AElement: TCodeElementInfo; const AModel: TXmlDocModel): Boolean;

    /// <summary>현재 탑뷰의 소스 에디터를 반환합니다.</summary>
    /// <returns>IOTASourceEditor. 없으면 nil</returns>
    class function GetCurrentSourceEditor: IOTASourceEditor;
  end;

implementation

{ TDocOTAWriter }

class function TDocOTAWriter.ApplyToEditor(const AEditor: IOTASourceEditor; const AElement: TCodeElementInfo; const AModel: TXmlDocModel): Boolean;
var
  LWriter: IOTAEditWriter;
  LCommentBlock: string;
  LStartPos: Integer;
  LEndPos: Integer;
  LUtf8: UTF8String;
begin
  Result := False;
  if not Assigned(AEditor) then
    Exit;

  LCommentBlock := TDocCodeGenerator.ModelToCommentBlock(AModel, AElement.IndentLevel);

  LWriter := AEditor.CreateUndoableWriter;
  if not Assigned(LWriter) then
    Exit;

  // Delphi IDE의 에디터 버퍼는 내부적으로 UTF-8로 동작.
  // 파일의 디스크 인코딩(ANSI/UTF-8 BOM/UTF-16 등)과 무관하게
  // IOTAEditWriter.Insert에는 항상 UTF-8 바이트를 전달해야 함.
  try
    if AModel.IsEmpty then
    begin
      // 빈 모델: 기존 주석 제거
      if AElement.CommentStartLine >= 0 then
      begin
        LStartPos := GetEditorPosition(AEditor, AElement.CommentStartLine, 1);
        LEndPos := GetEditorPosition(AEditor, AElement.CommentEndLine + 1, 1);
        if (LStartPos >= 0) and (LEndPos >= 0) then
        begin
          LWriter.CopyTo(LStartPos);
          LWriter.DeleteTo(LEndPos);
          Result := True;
        end;
      end;
    end
    else
    if AElement.CommentStartLine >= 0 then
    begin
      // 기존 주석 교체
      LStartPos := GetEditorPosition(AEditor, AElement.CommentStartLine, 1);
      LEndPos := GetEditorPosition(AEditor, AElement.CommentEndLine + 1, 1);
      if (LStartPos >= 0) and (LEndPos >= 0) then
      begin
        LUtf8 := UTF8Encode(LCommentBlock);
        LWriter.CopyTo(LStartPos);
        LWriter.DeleteTo(LEndPos);
        LWriter.Insert(PAnsiChar(LUtf8));
        Result := True;
      end;
    end
    else
    begin
      // 새 주석 삽입 (코드 요소 직전)
      LStartPos := GetEditorPosition(AEditor, AElement.LineNumber, 1);
      if LStartPos >= 0 then
      begin
        LUtf8 := UTF8Encode(LCommentBlock);
        LWriter.CopyTo(LStartPos);
        LWriter.Insert(PAnsiChar(LUtf8));
        Result := True;
      end;
    end;
  finally
    LWriter := nil;
  end;
end;

class function TDocOTAWriter.GetCurrentSourceEditor: IOTASourceEditor;
var
  LServices: IOTAEditorServices;
  LEditView: IOTAEditView;
  LModule: IOTAModule;
  I: Integer;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAEditorServices, LServices) then
    Exit;

  LEditView := LServices.TopView;
  if not Assigned(LEditView) then
    Exit;

  if not Assigned(LEditView.Buffer) then
    Exit;

  LModule := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if not Assigned(LModule) then
    Exit;

  for I := 0 to LModule.ModuleFileCount - 1 do
  begin
    if Supports(LModule.ModuleFileEditors[I], IOTASourceEditor, Result) then
      Exit;
  end;

  Result := nil;
end;

class function TDocOTAWriter.GetEditorPosition(const AEditor: IOTASourceEditor; ALine, ACol: Integer): Integer;
var
  LEditView: IOTAEditView;
  LPos: TOTACharPos;
begin
  Result := -1;
  if not Assigned(AEditor) then
    Exit;

  if AEditor.EditViewCount = 0 then
    Exit;

  LEditView := AEditor.EditViews[0];
  if not Assigned(LEditView) then
    Exit;

  LPos.Line := ALine;
  LPos.CharIndex := ACol - 1;
  Result := LEditView.CharPosToPos(LPos);
end;

end.
