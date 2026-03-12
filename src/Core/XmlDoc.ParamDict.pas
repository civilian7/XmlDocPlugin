unit XmlDoc.ParamDict;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections;

type
  /// <summary>프로젝트별 파라미터 설명 자동 완성 딕셔너리</summary>
  TParamDictionary = class
  strict private
    class var FInstance: TParamDictionary;

    class destructor Destroy;
  private
    FDirty: Boolean;
    FFilePath: string;
    FItems: TDictionary<string, string>;

    class function  GetInstance: TParamDictionary; static;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>딕셔너리 파일 경로를 설정하고 기존 데이터를 로드합니다.</summary>
    /// <param name="APath">JSON 파일 경로</param>
    procedure LoadFromFile(const APath: string);

    /// <summary>파라미터 설명을 등록합니다.</summary>
    /// <param name="AName">파라미터 이름</param>
    /// <param name="ADescription">파라미터 설명</param>
    procedure Register(const AName, ADescription: string);

    /// <summary>변경된 내용이 있으면 파일에 저장합니다.</summary>
    procedure SaveToFile;

    /// <summary>파라미터 설명을 조회합니다.</summary>
    /// <param name="AName">파라미터 이름</param>
    /// <param name="ADescription">조회된 설명 (출력)</param>
    /// <returns>설명이 존재하면 True</returns>
    function TryGet(const AName: string; out ADescription: string): Boolean;

    /// <summary>싱글톤 인스턴스를 반환합니다.</summary>
    class property Instance: TParamDictionary read GetInstance;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON;

{ TParamDictionary }

class destructor TParamDictionary.Destroy;
begin
  FreeAndNil(FInstance);
end;

constructor TParamDictionary.Create;
begin
  inherited Create;
  FItems := TDictionary<string, string>.Create;
  FDirty := False;
end;

destructor TParamDictionary.Destroy;
begin
  SaveToFile;
  FItems.Free;

  inherited;
end;

class function TParamDictionary.GetInstance: TParamDictionary;
begin
  if not Assigned(FInstance) then
    FInstance := TParamDictionary.Create;

  Result := FInstance;
end;

procedure TParamDictionary.LoadFromFile(const APath: string);
var
  LJson: string;
  LObj: TJSONObject;
  LPair: TJSONPair;
  I: Integer;
begin
  FFilePath := APath;
  FItems.Clear;
  FDirty := False;

  if not TFile.Exists(APath) then
    Exit;

  try
    LJson := TFile.ReadAllText(APath, TEncoding.UTF8);
    LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if Assigned(LObj) then
    begin
      try
        for I := 0 to LObj.Count - 1 do
        begin
          LPair := LObj.Pairs[I];
          FItems.AddOrSetValue(LPair.JsonString.Value, LPair.JsonValue.Value);
        end;
      finally
        LObj.Free;
      end;
    end;
  except
    // 파일 읽기/파싱 실패 시 빈 딕셔너리로 시작
  end;
end;

procedure TParamDictionary.Register(const AName, ADescription: string);
var
  LTrimmed: string;
  LExisting: string;
begin
  LTrimmed := Trim(ADescription);

  // 빈 값이나 TODO: 접두어는 무시
  if (LTrimmed = '') or LTrimmed.StartsWith('TODO:', True) then
    Exit;

  // 이름이 비어있으면 무시
  if Trim(AName) = '' then
    Exit;

  // 동일한 값이 이미 있으면 스킵
  if FItems.TryGetValue(AName, LExisting) and (LExisting = LTrimmed) then
    Exit;

  FItems.AddOrSetValue(AName, LTrimmed);
  FDirty := True;
end;

procedure TParamDictionary.SaveToFile;
var
  LObj: TJSONObject;
  LPair: TPair<string, string>;
  LSorted: TList<TPair<string, string>>;
  LJson: string;
begin
  if not FDirty then
    Exit;

  if FFilePath = '' then
    Exit;

  LObj := TJSONObject.Create;
  try
    // 키 알파벳순 정렬하여 저장
    LSorted := TList<TPair<string, string>>.Create;
    try
      for LPair in FItems do
        LSorted.Add(LPair);

      LSorted.Sort(TComparer<TPair<string, string>>.Construct(
        function(const ALeft, ARight: TPair<string, string>): Integer
        begin
          Result := CompareText(ALeft.Key, ARight.Key);
        end
      ));

      for LPair in LSorted do
        LObj.AddPair(LPair.Key, LPair.Value);
    finally
      LSorted.Free;
    end;

    LJson := LObj.Format(2);

    try
      ForceDirectories(ExtractFilePath(FFilePath));
      TFile.WriteAllText(FFilePath, LJson, TEncoding.UTF8);
      FDirty := False;
    except
      // 파일 쓰기 실패 시 무시 — 다음 기회에 재시도
    end;
  finally
    LObj.Free;
  end;
end;

function TParamDictionary.TryGet(const AName: string; out ADescription: string): Boolean;
begin
  Result := FItems.TryGetValue(AName, ADescription);
end;

end.
