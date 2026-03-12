unit SampleClass;

interface

type
  TMyClass = class
  private
    FName: string;
    FValue: Integer;

  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    procedure DoSomething(const AParam: string);
    function Calculate(AX, AY: Integer): Integer;

    property Name: string read FName write FName;
    property Value: Integer read FValue write FValue;
  end;

const
  DefaultValue = 42;

implementation

constructor TMyClass.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

destructor TMyClass.Destroy;
begin
  inherited;
end;

procedure TMyClass.DoSomething(const AParam: string);
begin
  // nothing
end;

function TMyClass.Calculate(AX, AY: Integer): Integer;
begin
  Result := AX + AY;
end;

end.
