unit SampleAllTags;

/// <summary>
/// Demonstrates all supported XML documentation tags.
/// This fixture covers every tag the XmlDoc Plugin supports.
/// </summary>

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  /// <summary>Represents a user account in the system.</summary>
  /// <remarks>
  /// <para>This class is thread-safe. All public methods acquire an internal lock before modifying state.</para>
  /// <para>Use <see cref="TUserManager"/> to create and manage <c>TUser</c> instances.</para>
  /// </remarks>
  /// <seealso cref="TUserManager"/>
  TUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
  public
    constructor Create(AId: Integer; const AName, AEmail: string);

    /// <summary>The unique identifier of the user.</summary>
    /// <value>A positive integer assigned upon creation.</value>
    property Id: Integer read FId;

    /// <summary>The display name of the user.</summary>
    /// <value>A non-empty string representing the user's full name.</value>
    property Name: string read FName write FName;

    /// <summary>The email address of the user.</summary>
    /// <value>A valid email address string.</value>
    property Email: string read FEmail write FEmail;
  end;

  /// <summary>Custom exception raised when a requested user is not found.</summary>
  /// <remarks>Thrown by <see cref="TUserManager.GetUser"/> and <see cref="TUserManager.UpdateUser"/>.</remarks>
  EUserNotFoundException = class(Exception);

  /// <summary>Custom exception raised when input validation fails.</summary>
  EValidationException = class(Exception);

  /// <summary>A generic container that caches items by key.</summary>
  /// <typeparam name="TKey">The type of the cache key. Must support equality comparison.</typeparam>
  /// <typeparam name="TValue">The type of the cached value.</typeparam>
  /// <remarks>
  /// <para>Items are stored in a <c>TDictionary</c> internally.</para>
  /// <para>The cache does not implement automatic eviction. Call <see cref="Clear"/> to remove all entries.</para>
  /// </remarks>
  TCache<TKey, TValue> = class
  private
    FDict: TDictionary<TKey, TValue>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Adds or updates an item in the cache.</summary>
    /// <param name="AKey">The key to associate with the value.</param>
    /// <param name="AValue">The value to cache.</param>
    procedure Put(const AKey: TKey; const AValue: TValue);

    /// <summary>Retrieves a cached item by key.</summary>
    /// <param name="AKey">The key to look up.</param>
    /// <returns>The cached value associated with <paramref name="AKey"/>.</returns>
    /// <exception cref="EKeyNotFoundException">Raised when <paramref name="AKey"/> is not found in the cache.</exception>
    function Get(const AKey: TKey): TValue;

    /// <summary>Tries to retrieve a cached item without raising an exception.</summary>
    /// <param name="AKey">The key to look up.</param>
    /// <param name="AValue">When this method returns, contains the value if found; otherwise the default value for <typeparamref name="TValue"/>.</param>
    /// <returns><c>True</c> if <paramref name="AKey"/> was found; otherwise <c>False</c>.</returns>
    function TryGet(const AKey: TKey; out AValue: TValue): Boolean;

    /// <summary>Removes all items from the cache.</summary>
    procedure Clear;

    /// <summary>Returns the number of items currently in the cache.</summary>
    /// <returns>A non-negative integer representing the item count.</returns>
    function Count: Integer;
  end;

  /// <summary>Manages user accounts and provides CRUD operations.</summary>
  /// <remarks>
  /// <para>This is the main entry point for user management operations.</para>
  /// <para>All methods validate their inputs and raise <see cref="EValidationException"/> on invalid arguments.</para>
  /// </remarks>
  /// <seealso cref="TUser"/>
  /// <seealso cref="EUserNotFoundException"/>
  TUserManager = class
  private
    FUsers: TObjectList<TUser>;
    FCache: TCache<Integer, TUser>;
    FNextId: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Creates a new user with the specified name and email.</summary>
    /// <param name="AName">The display name for the new user. Must not be empty.</param>
    /// <param name="AEmail">The email address for the new user. Must contain <c>@</c>.</param>
    /// <returns>The newly created <see cref="TUser"/> instance.</returns>
    /// <exception cref="EValidationException">Raised when <paramref name="AName"/> is empty or <paramref name="AEmail"/> is invalid.</exception>
    /// <example>
    /// <code>
    /// var LUser := UserMgr.CreateUser('John Doe', 'john@example.com');
    /// WriteLn('Created user ID: ', LUser.Id);
    /// </code>
    /// </example>
    function CreateUser(const AName, AEmail: string): TUser;

    /// <summary>Retrieves a user by their unique identifier.</summary>
    /// <param name="AUserId">The ID of the user to retrieve.</param>
    /// <returns>The <see cref="TUser"/> with the matching ID.</returns>
    /// <exception cref="EUserNotFoundException">Raised when no user with <paramref name="AUserId"/> exists.</exception>
    function GetUser(AUserId: Integer): TUser;

    /// <summary>Updates the name and email of an existing user.</summary>
    /// <param name="AUserId">The ID of the user to update.</param>
    /// <param name="ANewName">The new display name. Pass empty string to keep unchanged.</param>
    /// <param name="ANewEmail">The new email address. Pass empty string to keep unchanged.</param>
    /// <returns><c>True</c> if the user was found and updated; <c>False</c> otherwise.</returns>
    /// <exception cref="EUserNotFoundException">Raised when no user with <paramref name="AUserId"/> exists.</exception>
    /// <exception cref="EValidationException">Raised when <paramref name="ANewEmail"/> is non-empty but does not contain <c>@</c>.</exception>
    /// <example>
    /// <code>
    /// if UserMgr.UpdateUser(42, 'Jane Doe', 'jane@example.com') then
    ///   WriteLn('User updated successfully');
    /// </code>
    /// </example>
    /// <seealso cref="TUserManager.GetUser"/>
    function UpdateUser(AUserId: Integer; const ANewName, ANewEmail: string): Boolean;

    /// <summary>Deletes a user by their unique identifier.</summary>
    /// <param name="AUserId">The ID of the user to delete.</param>
    /// <exception cref="EUserNotFoundException">Raised when no user with <paramref name="AUserId"/> exists.</exception>
    procedure DeleteUser(AUserId: Integer);

    /// <summary>Returns the total number of users.</summary>
    /// <returns>A non-negative integer.</returns>
    function UserCount: Integer;
  end;

  /// <summary>Defines the contract for a serialization provider.</summary>
  /// <remarks>Implement this interface to add custom serialization formats.</remarks>
  ISerializer = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    /// <summary>Serializes a user object to a string representation.</summary>
    /// <param name="AUser">The user to serialize. Must not be <c>nil</c>.</param>
    /// <returns>A string representation of the user in the target format.</returns>
    function Serialize(AUser: TUser): string;

    /// <summary>Deserializes a string representation back to a user object.</summary>
    /// <param name="AData">The string data to deserialize.</param>
    /// <returns>A new <see cref="TUser"/> instance populated from <paramref name="AData"/>.</returns>
    /// <exception cref="EValidationException">Raised when <paramref name="AData"/> is malformed.</exception>
    function Deserialize(const AData: string): TUser;
  end;

const
  /// <summary>The maximum number of users allowed in the system.</summary>
  MAX_USERS = 10000;

  /// <summary>The default email domain used when no domain is specified.</summary>
  DEFAULT_DOMAIN = 'example.com';

implementation

{ TUser }

/// <summary>Creates a new user instance.</summary>
/// <param name="AId">The unique identifier.</param>
/// <param name="AName">The display name.</param>
/// <param name="AEmail">The email address.</param>
constructor TUser.Create(AId: Integer; const AName, AEmail: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
  FEmail := AEmail;
end;

{ TCache<TKey, TValue> }

constructor TCache<TKey, TValue>.Create;
begin
  inherited Create;
  FDict := TDictionary<TKey, TValue>.Create;
end;

destructor TCache<TKey, TValue>.Destroy;
begin
  FDict.Free;
  inherited;
end;

procedure TCache<TKey, TValue>.Clear;
begin
  FDict.Clear;
end;

function TCache<TKey, TValue>.Count: Integer;
begin
  Result := FDict.Count;
end;

function TCache<TKey, TValue>.Get(const AKey: TKey): TValue;
begin
  Result := FDict[AKey];
end;

procedure TCache<TKey, TValue>.Put(const AKey: TKey; const AValue: TValue);
begin
  FDict.AddOrSetValue(AKey, AValue);
end;

function TCache<TKey, TValue>.TryGet(const AKey: TKey; out AValue: TValue): Boolean;
begin
  Result := FDict.TryGetValue(AKey, AValue);
end;

{ TUserManager }

constructor TUserManager.Create;
begin
  inherited Create;
  FUsers := TObjectList<TUser>.Create(True);
  FCache := TCache<Integer, TUser>.Create;
  FNextId := 1;
end;

destructor TUserManager.Destroy;
begin
  FCache.Free;
  FUsers.Free;
  inherited;
end;

function TUserManager.CreateUser(const AName, AEmail: string): TUser;
begin
  if AName.IsEmpty then
    raise EValidationException.Create('Name must not be empty');

  if not AEmail.Contains('@') then
    raise EValidationException.Create('Invalid email address');

  Result := TUser.Create(FNextId, AName, AEmail);
  Inc(FNextId);
  FUsers.Add(Result);
  FCache.Put(Result.Id, Result);
end;

function TUserManager.GetUser(AUserId: Integer): TUser;
var
  LUser: TUser;
begin
  if FCache.TryGet(AUserId, LUser) then
    Exit(LUser);

  for LUser in FUsers do
  begin
    if LUser.Id = AUserId then
      Exit(LUser);
  end;

  raise EUserNotFoundException.CreateFmt('User with ID %d not found', [AUserId]);
end;

function TUserManager.UpdateUser(AUserId: Integer; const ANewName, ANewEmail: string): Boolean;
var
  LUser: TUser;
begin
  LUser := GetUser(AUserId);

  if (ANewEmail <> '') and not ANewEmail.Contains('@') then
    raise EValidationException.Create('Invalid email address');

  if ANewName <> '' then
    LUser.Name := ANewName;

  if ANewEmail <> '' then
    LUser.Email := ANewEmail;

  Result := True;
end;

procedure TUserManager.DeleteUser(AUserId: Integer);
var
  I: Integer;
begin
  for I := FUsers.Count - 1 downto 0 do
  begin
    if FUsers[I].Id = AUserId then
    begin
      FUsers.Delete(I);
      Exit;
    end;
  end;

  raise EUserNotFoundException.CreateFmt('User with ID %d not found', [AUserId]);
end;

function TUserManager.UserCount: Integer;
begin
  Result := FUsers.Count;
end;

end.
