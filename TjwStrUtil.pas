unit TjwStrUtil;

interface

function StrHasSuffix(S, Suffix: String): Boolean;

// Returns A + B, except Sep is interposed if both A and B are nonempty.
function ConcatWithSep(A, B: string; Sep: string = ' '): String;

// Returns true if S is Prefix plus an optional numeric suffix, separated by Sep.
function IsPrefixPlusIntegerSuffix(S, Prefix: String; Sep: String = ' '): Boolean;

// Returns the integer suffix from S, or DefValue if it has none.
function GetIntegerSuffix(S: String; DefValue: Integer = -1): Integer;

// If the given string has an integer suffix, increment it.
// Otherwise, give it a suffix of '1', with the given separator.
function IncrementIntegerSuffix(S: String; Sep: String = ' '): String;

{ Models the returned string after the given model string.
	Model values:
		1: Arabic numbers
		i: Roman numbers, lowercase
		I: Roman numbers, uppercase
		a: Latin alphabet, lowercase; double (treble...) them for duplicates
		A: Latin alphabet, uppercase
		'': nothing is returned

	In all cases, 1 becomes the element listed.
}
{$ifdef USE_VCL}
function IntToStrModeled(Value: Integer; Model: String): String;
{$endif USE_VCL}

{ Converts a standard one-word code identifier into a phrase for display.
	Breaks words at changes in capitalization and at underscores, and
	capitalizes the following word.
	Omits a single initial capital T followed by another capital letter followed
	by a lower case letter.
	(for use with Delphi classes).
	E.g.:
		TMyClass -> My Class
		ThisThing_One -> This Thing One
		TLASet -> TLA Set
		AnotherTLA -> Another TLA
		XYZZY -> XYZZY
}
function DisplayFromID(ID: String): String;

// There's also JclHasPrefix/Suffix from JclStrings,
// but that requires an array.  This has slightly better syntax and performance when you only have one prefix.
function HasPrefix(S: string; Prefix: string): Boolean;
function HasSuffix(S: string; Suffix: string): Boolean;

// Removes Prefix or Suffix from S if found.
// Returns S, as modified.
function RemovePrefix(const S, Prefix: String): String;
function RemoveSuffix(const S, Suffix: String): String;

// If S doesn't end with Suffix, add it.  Return the result.
function EnsureSuffix(const S, Suffix: string): string;

// Trims the string so it contains no more than MaxLen characters.
// If AtSpace is true, tries to trim at whitespace if there is any.
// Always ends the string with an ellipsis if something was trimmed.
// (So, values of MaxLen < 3 may be violated.)
function TrimWithEllipsis(S: String; MaxLen: Integer; AtSpace: Boolean = true): String;

// Converts all substrings of whitespace characters into a single character.
function ConsolidateWhitespace(S: String): String;

// Simple shorthand functions for simple situations.
function FirstChar(S: String): Char;
function LastChar(S: String): Char;
function DeleteLastChar(S: String): String;
function DeleteFirstChar(S: String): String;

// Returns the length of the prefix or suffix that the two strings have in common.
// Uses case-sensitive matching.
function CommonPrefixLen(const A, B: string): Integer;
function CommonSuffixLen(const A, B: string): Integer;

// Returns S with any control characters deleted.
function RemoveControlChars(const S: string): string;

// Returns S in Title case.
// At present, just capitalizes the first character and lowercases the rest - no subsequent words.
function TitleCase(const S: string): string;

implementation

uses StrUtils, SysUtils, JclStrings, Math, CType
  {$ifdef USE_VCL}
  , JvJclUtils, JvStrings
  {$endif}
  ;

function StrHasSuffix(S, Suffix: String): Boolean;
begin
	Result := Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix
end;

function ConcatWithSep(A, B: string; Sep: string = ' '): String;
begin
	if (A <> '') and (B <> '') then
		Result := A + Sep + B
	else
		Result := A + B
end;

function IsPrefixPlusIntegerSuffix(S, Prefix: String; Sep: String = ' '): Boolean;
begin
	Result := (S = Prefix)
		or (
			StrHasPrefix(S, [Prefix + Sep])
			and StrConsistsofNumberChars(Copy(S, Length(Prefix) + Length(Sep) + 1, Length(S)))
		)
end;

function GetIntegerSuffix(S: String; DefValue: Integer = -1): Integer;
var
	suffixIndex, place: Integer;
begin
	// Look for an existing suffix.
	Result := 0;
	place := 1;
	suffixIndex := Length(S) + 1;
	while (suffixIndex > 1) and (CharIsNumberChar(S[suffixIndex - 1])) do begin
		Inc(Result, (Ord(S[suffixIndex - 1]) - Ord('0')) * place);
		Dec(suffixIndex);
		place := place * 10;
	end;

	if suffixIndex > Length(S) then
		// No suffix was found.
		Result := DefValue
end;

function IncrementIntegerSuffix(S: String; Sep: String = ' '): String;
var
	suffixIndex, suffixValue, place: Integer;
begin
	// Look for an existing suffix.
	suffixValue := 0;
	place := 1;
	suffixIndex := Length(S) + 1;
	while (suffixIndex > 1) and (CharIsNumberChar(S[suffixIndex - 1])) do begin
		Inc(suffixValue, (Ord(S[suffixIndex - 1]) - Ord('0')) * place);
		Dec(suffixIndex);
		place := place * 10;
	end;

	if suffixIndex > Length(S) then
		// No suffix was found.
		// Add one.
		Result := ConcatWithSep(S, '1', Sep)
	else
		// There is an existing numeric suffix.
		// Replace it.
		Result := Copy(S, 1, suffixIndex - 1) + IntToStr(suffixValue + 1);
end;

{$ifdef USE_VCL}
function IntToStrModeled(Value: Integer; Model: String): String;
begin
	if Model = '' then
		Result := ''
	else
		case Model[1] of
			'a', 'A': Result := DupeString(Chr(Ord(Model[1]) + (Value - 1) mod 26), (Value - 1) div 26 + 1);

			'i': Result := LowerCase(IntToRoman(Value));
			'I': Result := UpperCase(IntToRoman(Value));

			else
				Result := IntToStr(Value);
		end;
end;
{$endif USE_VCL}

function DisplayFromID(ID: String): String;
var
	i: Integer;
	lastWasInsertedSpace, lastWasUpper: Boolean;

	procedure AddChar(C: Char);
	begin
		Result := Result + C;
		lastWasInsertedSpace := CharIsSpace(C);
		lastWasUpper := CharIsUpper(C);
	end;

	procedure InsertSpaceIfNotAlready;
	begin
		if not lastWasInsertedSpace then
			AddChar(' ');
	end;

begin
	Result := '';

	lastWasUpper := true;
	lastWasInsertedSpace := true;

	for i := 1 to Length(ID) do
		if (i = 1) and (ID[i] = 'T') and (Length(ID) > 2) and CharIsUpper(ID[2]) and CharIsLower(ID[3]) then
			// skip initial 'T' followed by another capital
			// |TMyClass -> My Class
		else if CharIsUpper(ID[i]) then begin
			// We're at:
			// T|My|Class -> My Class
			// |This|Thing_|One -> This Thing One
			// |T|L|A|Set -> TLA Set
			// |Another|T|L|A -> Another TLA
			// |X|Y|Z|Z|Y -> XYZZY
			if (not lastWasUpper)
				or ((Length(ID) > i + 1) and CharIsLower(ID[i + 1]))
			then
				// We're at:
				// TMy|Class -> My Class
				// This|Thing_|One -> This Thing One
				// TLA|Set -> TLA Set
				// Another|TLA -> Another TLA
				// XYZZY -> XYZZY
				InsertSpaceIfNotAlready;

			AddChar(ID[i]);
		end else if not CharIsAlphaNum(ID[i]) then
			// We're at:
			// ThisThing|_One -> This Thing One
			// ThisThing|_|_One -> This Thing One
			InsertSpaceIfNotAlready
		else
			// Insert everything else.
			AddChar(ID[i]);
end;

function HasPrefix(S, Prefix: string): Boolean;
begin
  if Length(S) >= Length(Prefix) then
    Result := SameText(StrLeft(S, Length(Prefix)), Prefix)
  else
    Result := False;
end;

function HasSuffix(S, Suffix: string): Boolean;
begin
  if Length(S) >= Length(Suffix) then
    Result := SameText(StrRight(S, Length(Suffix)), Suffix)
  else
    Result := False;
end;

function RemovePrefix(const S, Prefix: String): string;
begin
  if HasPrefix(S, Prefix) then
    Result := Copy(S, Length(Prefix) + 1)
  else
    Result := S;
end;

function RemoveSuffixLen(const S: string; SuffixLen: longint): string;
begin
  Result := Copy(S, 1, length(S) - SuffixLen);
end;

function RemoveSuffix(const S, Suffix: string): string;
begin
  if HasSuffix(S, Suffix) then
    Result := RemoveSuffixLen(S, Length(Suffix))
  else
    Result := S;
end;

function EnsureSuffix(const S, Suffix: string): string;
begin
  if not HasSuffix(S, Suffix) then
    Result := S + Suffix
  else
    Result := S;
end;

function TrimWithEllipsis(S: String; MaxLen: Integer; AtSpace: Boolean = true): String;
const
	ellipsis = '...';
var
	i: Integer;
begin
	if Length(S) > MaxLen then begin
		for i := MaxLen - Length(ellipsis) downto 1 do
			if (not AtSpace) or CharIsWhiteSpace(S[i]) then begin
				Result := TrimLeft(Copy(S, 1, i-1)) + ellipsis;
				Exit;
			end;

		// Couldn't find any whitespace.
		// Just hack it off.
		Result := Copy(S, 1, MaxLen - Length(ellipsis)) + ellipsis;
	end else
		Result := S;
end;

function ConsolidateWhitespace(S: String): String;
var
	i: Integer;
begin
	Result := '';

	for i := 1 to Length(S) do
		if CharIsWhiteSpace(S[i]) then begin
			if (Result = '') or (LastChar(Result) <> ' ') then
				Result := Result + ' '
		end else
			Result := Result + S[i];
end;

function FirstChar(S: String): Char;
begin
	Result := S[1]
end;

function LastChar(S: String): Char;
begin
	Result := S[Length(S)]
end;

function DeleteLastChar(S: String): String;
begin
	Result := Copy(S, 1, Length(S) - 1);
end;

function DeleteFirstChar(S: String): String;
begin
	Result := Copy(S, 2, Length(S) - 1);
end;

function CommonPrefixLen(const A, B: string): Integer;
var
	maxI: Integer;
begin
	maxI := Min(Length(A), Length(B));

	Result := 0;
	while Result < maxI do
		if A[Result + 1] <> B[Result + 1] then
			Exit
		else
			Inc(Result);
end;

function CommonSuffixLen(const A, B: string): Integer;
var
	maxI: Integer;
begin
	maxI := Min(Length(A), Length(B));

	Result := 0;
	while Result < maxI do
		if A[Length(A) - 1 - Result] <> B[Length(B) - 1 - Result] then
			Exit
		else
			Inc(Result);
end;

function RemoveControlChars(const S: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    if S[i] >= ' ' then
      Result := Result + S[i];
end;

function TitleCase(const S: string): string;
begin
  if Length(S) = 0 then
    Result := ''
  else if Length(S) = 1 then
    Result := StrUpper(S)
  else
    Result := StrUpper(S[1]) + StrLower(StrRestOf(S, 2));
end;

end.
