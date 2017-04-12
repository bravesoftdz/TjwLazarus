unit CType;

interface

{$ifdef DELPHI}
uses
  Character;
{$else}
function IsUpper(c: Char): Boolean;
function IsLower(c: Char): Boolean;
function IsLetter(c: Char): Boolean;
function IsNumber(c: Char): Boolean;
function IsWhitespace(c: Char): Boolean;
{$endif}

function IsPrintable(c: AnsiChar): Boolean;
function IsPrintableAnsi(c: Char): Boolean;
function IsDecimal(c: Char): Boolean;  // allows '.', '+', '-'

// Returns the character, if it's in the printable ANSI range (32..127);
// otherwise, returns #0.
function PrintableAnsi(c: Char): AnsiChar;

{ like the character counterparts, but the string must be nonempty
  and all characters in it must fit the criterion. }
function IsStringUpper(s: String): Boolean;
function IsStringLower(s: String): Boolean;
function IsStringAlpha(s: String): Boolean;
function IsStringNum(s: String): Boolean;
function IsStringDecimal(s: String): Boolean;  // allows '.', '+', '-'
function IsStringWhitespace(s: String): Boolean;


implementation

uses
  System.SysUtils;

type
	TCharPredicate = function(c: Char): Boolean;

{$ifndef DELPHI}
function IsUpper(c: Char): Boolean;
begin
  Result := (c >= 'A') and (c <= 'Z');
end;

function IsLower(c: Char): Boolean;
begin
  Result := (c >= 'a') and (c <= 'z');
end;

function IsLetter(c: Char): Boolean;
begin
	IsLetter := IsUpper(c) or IsLower(c);
end;

function IsNumber(c: Char): Boolean;
begin
	Result := (c >= '0') and (c <= '9');
end;

function IsWhitespace(c: Char): Boolean;
begin
	Result := CharInSet(C, [' ', #10, #13, #9]);
end;
{$endif}

function IsPrintable(c: AnsiChar): Boolean;
begin
	Result := (c >= ' ') and (c <= '~');
end;

function IsPrintableAnsi(c: Char): Boolean;
begin
  Result := (c >= ' ') and (c <= '~');
end;

function PrintableAnsi(c: Char): AnsiChar;
begin
  if IsPrintableAnsi(c) then
    Result := AnsiChar(c)
  else
    Result := #0
end;

function IsDecimal(c: Char): Boolean;
begin
	Result := IsNumber(c) or (c = '.') or (c = '+') or (c = '-')
end;


function StringMatches(s: String; Predicate: TCharPredicate): Boolean;
var
	i: Integer;
begin
	if Length(s) = 0 then
		Result := false
	else begin
		Result := true;
		for i := 1 to Length(s) do
			if not Predicate(s[i]) then begin
				Result := false;
				Break;
			end;
	end;
end;

function IsStringUpper(s: String): Boolean;
begin
	Result := StringMatches(s, @IsUpper)
end;

function IsStringLower(s: String): Boolean;
begin
	Result := StringMatches(s, @IsLower)
end;

function IsStringAlpha(s: String): Boolean;
begin
	Result := StringMatches(s, @IsLetter)
end;

function IsStringNum(s: String): Boolean;
begin
	Result := StringMatches(s, @IsNumber)
end;

function IsStringDecimal(s: String): Boolean;
begin
	Result := StringMatches(s, @IsDecimal)
end;

function IsStringWhitespace(s: String): Boolean;
begin
	Result := StringMatches(s, @IsWhitespace)
end;

end.
