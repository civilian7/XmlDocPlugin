unit XmlDoc.HelpGen.Scanner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Masks;

type
  /// <summary>스캔 소스 유형</summary>
  TScanSource = (
    ssProjectFile,
    ssDirectory,
    ssFileList
  );

  /// <summary>프로젝트 스캔 옵션</summary>
  TScanOptions = record
    Source: TScanSource;
    ProjectPath: string;
    FileList: TArray<string>;
    ExcludePatterns: TArray<string>;
    SearchPaths: TArray<string>;
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
  end;

  /// <summary>프로젝트 파일을 스캔하여 문서화 대상 .pas 파일 목록을 수집합니다.</summary>
  TProjectScanner = class
  private
    function IsExcluded(const AFilePath: string; const APatterns: TArray<string>): Boolean;
    function ParseProjectUses(const AProjectPath: string): TArray<string>;
    function ResolveMainSource(const ADprojPath: string): string;
    function ResolveUnitPath(const AUnitName, AProjectDir: string;
      const ASearchPaths: TArray<string>): string;
    function ScanDirectory(const ADirPath: string): TArray<string>;

  public
    /// <summary>옵션에 따라 .pas 파일 목록을 수집합니다.</summary>
    /// <param name="AOptions">스캔 옵션</param>
    /// <returns>절대 경로의 .pas 파일 배열</returns>
    function Scan(const AOptions: TScanOptions): TArray<string>;
  end;

implementation

function IsLetterOrDigit(ACh: Char): Boolean;
begin
  Result := CharInSet(ACh, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

{ TProjectScanner }

function TProjectScanner.IsExcluded(const AFilePath: string;
  const APatterns: TArray<string>): Boolean;
var
  LFileName: string;
  I: Integer;
begin
  Result := False;
  LFileName := ExtractFileName(AFilePath);

  for I := 0 to Length(APatterns) - 1 do
  begin
    if MatchesMask(LFileName, APatterns[I]) then
    begin
      Result := True;
      Exit;
    end;

    // 경로 패턴도 체크
    if MatchesMask(AFilePath, APatterns[I]) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TProjectScanner.ResolveMainSource(const ADprojPath: string): string;
var
  LSource: TStringList;
  LText: string;
  LStartPos: Integer;
  LEndPos: Integer;
  LMainSource: string;
  LProjectDir: string;
begin
  Result := '';
  LProjectDir := ExtractFilePath(ADprojPath);

  LSource := TStringList.Create;
  try
    LSource.LoadFromFile(ADprojPath, TEncoding.UTF8);
    LText := LSource.Text;
  finally
    LSource.Free;
  end;

  // <MainSource>FileName.dpk</MainSource> 추출
  LStartPos := Pos('<MainSource>', LText);
  if LStartPos = 0 then
    Exit;

  LStartPos := LStartPos + Length('<MainSource>');
  LEndPos := Pos('</MainSource>', LText);
  if LEndPos <= LStartPos then
    Exit;

  LMainSource := Trim(Copy(LText, LStartPos, LEndPos - LStartPos));
  if LMainSource = '' then
    Exit;

  Result := TPath.GetFullPath(TPath.Combine(LProjectDir, LMainSource));
  if not TFile.Exists(Result) then
    Result := '';
end;

function TProjectScanner.ParseProjectUses(const AProjectPath: string): TArray<string>;
var
  LSource: TStringList;
  LText: string;
  LInSection: Boolean;
  LProjectDir: string;
  LSourcePath: string;
  I: Integer;
  LLine: string;
  LTrimmed: string;
  LLower: string;
  LParts: TArray<string>;
  LUnitName: string;
  LInPath: string;
  LResolvedPath: string;
  LResults: TList<string>;
  LInlinePos: Integer;
  LKeywordLen: Integer;
begin
  LProjectDir := ExtractFilePath(AProjectPath);
  LSourcePath := AProjectPath;

  // .dproj 파일이면 MainSource를 찾아 실제 소스 파일로 전환
  if SameText(ExtractFileExt(AProjectPath), '.dproj') then
  begin
    LSourcePath := ResolveMainSource(AProjectPath);
    if LSourcePath = '' then
    begin
      Result := nil;
      Exit;
    end;
    LProjectDir := ExtractFilePath(LSourcePath);
  end;

  LResults := TList<string>.Create;
  try
    LSource := TStringList.Create;
    try
      LSource.LoadFromFile(LSourcePath, TEncoding.UTF8);
      LText := LSource.Text;
    finally
      LSource.Free;
    end;

    // uses 또는 contains 절 파싱
    LInSection := False;
    LSource := TStringList.Create;
    try
      LSource.Text := LText;
      for I := 0 to LSource.Count - 1 do
      begin
        LLine := LSource[I];
        LTrimmed := Trim(LLine);

        // 한 줄 주석 제거
        if LTrimmed.StartsWith('//') then
          Continue;

        if not LInSection then
        begin
          LLower := LowerCase(LTrimmed);
          LKeywordLen := 0;

          if LLower.StartsWith('uses') and
             ((Length(LTrimmed) = 4) or not IsLetterOrDigit(LTrimmed[5])) then
            LKeywordLen := 4
          else if LLower.StartsWith('contains') and
                  ((Length(LTrimmed) = 8) or not IsLetterOrDigit(LTrimmed[9])) then
            LKeywordLen := 8;

          if LKeywordLen > 0 then
          begin
            LInSection := True;
            LTrimmed := Trim(Copy(LTrimmed, LKeywordLen + 1, MaxInt));
          end
          else
            Continue;
        end;

        if LInSection then
        begin
          // 세미콜론으로 절 종료
          if LTrimmed.Contains(';') then
          begin
            LTrimmed := Copy(LTrimmed, 1, Pos(';', LTrimmed) - 1);
            LInSection := False;
          end;

          // 콤마로 분리된 유닛 이름들 처리
          LParts := LTrimmed.Split([',']);
          for LUnitName in LParts do
          begin
            LTrimmed := Trim(LUnitName);
            if LTrimmed = '' then
              Continue;

            // 'in' 키워드로 인라인 경로 처리
            LInlinePos := Pos(' in ', LowerCase(LTrimmed));
            if LInlinePos > 0 then
            begin
              LInPath := Trim(Copy(LTrimmed, LInlinePos + 4, MaxInt));
              LTrimmed := Trim(Copy(LTrimmed, 1, LInlinePos - 1));
              // 따옴표 제거
              LInPath := StringReplace(LInPath, '''', '', [rfReplaceAll]);
              LInPath := Trim(LInPath);
              LResolvedPath := TPath.GetFullPath(TPath.Combine(LProjectDir, LInPath));
              if TFile.Exists(LResolvedPath) then
                LResults.Add(LResolvedPath);
            end
            else
            begin
              // 검색 경로에서 유닛 찾기
              LResolvedPath := ResolveUnitPath(LTrimmed, LProjectDir, []);
              if LResolvedPath <> '' then
                LResults.Add(LResolvedPath);
            end;
          end;
        end;
      end;
    finally
      LSource.Free;
    end;

    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

function TProjectScanner.ResolveUnitPath(const AUnitName, AProjectDir: string;
  const ASearchPaths: TArray<string>): string;
var
  LPasFile: string;
  I: Integer;
  LPath: string;
begin
  Result := '';
  LPasFile := AUnitName + '.pas';

  // 1. 프로젝트 디렉토리에서 검색
  LPath := TPath.Combine(AProjectDir, LPasFile);
  if TFile.Exists(LPath) then
  begin
    Result := TPath.GetFullPath(LPath);
    Exit;
  end;

  // 2. 검색 경로에서 검색
  for I := 0 to Length(ASearchPaths) - 1 do
  begin
    LPath := TPath.Combine(ASearchPaths[I], LPasFile);
    if TFile.Exists(LPath) then
    begin
      Result := TPath.GetFullPath(LPath);
      Exit;
    end;
  end;
end;

function TProjectScanner.ScanDirectory(const ADirPath: string): TArray<string>;
var
  LFiles: TArray<string>;
begin
  if not TDirectory.Exists(ADirPath) then
  begin
    Result := nil;
    Exit;
  end;

  LFiles := TDirectory.GetFiles(ADirPath, '*.pas', TSearchOption.soAllDirectories);
  Result := LFiles;
end;

function TProjectScanner.Scan(const AOptions: TScanOptions): TArray<string>;
var
  LRawFiles: TArray<string>;
  LFiltered: TList<string>;
  I: Integer;
  LFilePath: string;
begin
  case AOptions.Source of
  ssProjectFile:
    begin
      LRawFiles := ParseProjectUses(AOptions.ProjectPath);

      // 추가 검색 경로로 미해결 유닛 재시도
      if Length(AOptions.SearchPaths) > 0 then
      begin
        LFiltered := TList<string>.Create;
        try
          for I := 0 to Length(LRawFiles) - 1 do
            LFiltered.Add(LRawFiles[I]);

          // 프로젝트 디렉토리에서 사용자 지정 검색 경로 추가 탐색
          LRawFiles := LFiltered.ToArray;
        finally
          LFiltered.Free;
        end;
      end;
    end;
  ssDirectory:
    LRawFiles := ScanDirectory(AOptions.ProjectPath);
  ssFileList:
    LRawFiles := AOptions.FileList;
  else
    LRawFiles := nil;
  end;

  // 제외 패턴 필터링
  if Length(AOptions.ExcludePatterns) > 0 then
  begin
    LFiltered := TList<string>.Create;
    try
      for I := 0 to Length(LRawFiles) - 1 do
      begin
        LFilePath := LRawFiles[I];
        if not IsExcluded(LFilePath, AOptions.ExcludePatterns) then
          LFiltered.Add(LFilePath);
      end;
      Result := LFiltered.ToArray;
    finally
      LFiltered.Free;
    end;
  end
  else
    Result := LRawFiles;
end;

end.
