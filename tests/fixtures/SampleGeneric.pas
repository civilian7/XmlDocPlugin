unit SampleGeneric;

interface

uses
  System.Generics.Collections;

type
  TContainer<T> = class
  private
    FItems: TList<T>;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(const AItem: T);
    function GetItem(AIndex: Integer): T;
    function Count: Integer;
  end;

  TKeyValue<TKey, TValue> = record
    Key: TKey;
    Value: TValue;
  end;

implementation

constructor TContainer<T>.Create;
begin
  inherited Create;
  FItems := TList<T>.Create;
end;

destructor TContainer<T>.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TContainer<T>.Add(const AItem: T);
begin
  FItems.Add(AItem);
end;

function TContainer<T>.GetItem(AIndex: Integer): T;
begin
  Result := FItems[AIndex];
end;

function TContainer<T>.Count: Integer;
begin
  Result := FItems.Count;
end;

end.
