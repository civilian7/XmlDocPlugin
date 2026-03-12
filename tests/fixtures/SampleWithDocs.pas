unit SampleWithDocs;

interface

type
  /// <summary>사용자 데이터를 관리하는 클래스</summary>
  /// <remarks>스레드 세이프하며, 내부적으로 잠금을 사용합니다.</remarks>
  TUserManager = class
  public
    /// <summary>사용자 정보를 업데이트합니다.</summary>
    /// <param name="AUserId">대상 사용자 ID</param>
    /// <param name="ANewName">새로운 이름</param>
    /// <returns>업데이트 성공 여부</returns>
    /// <exception cref="EUserNotFoundException">사용자를 찾을 수 없을 때 발생</exception>
    function UpdateUser(AUserId: Integer; const ANewName: string): Boolean;

    /// <summary>사용자를 삭제합니다.</summary>
    /// <param name="AUserId">삭제할 사용자 ID</param>
    procedure DeleteUser(AUserId: Integer);

    procedure NoDocMethod(const AValue: string);
  end;

implementation

end.
