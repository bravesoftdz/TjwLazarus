unit MruMenu;
(*
	TMruMenu Component: Most-Recently-Used file list
	by Timothy Weber

	Supports Delphi 1, 2, 3, 5, 7, 2010, and XE3.

	Usage: Fill in the BeforeItem and AfterItem properties.  Then call AddFile
	whenever a file is opened, and respond to OnClick as you would to a File|Open
	command.

	BeforeItem: The menu item that comes before the MRU items.  Usually a
	separator item.

	AfterItem: The menu item that comes after the MRU items.  Usually the Exit
	item.

	OnClick: This event is called when the user chooses one of the MRU items.
	Handle it like you would a File|Open event that's passed the given file name.

	AddFile: Call this from your normal File|Open handler, to register the opened
	file.  Don't call it from within OnClick.

	LastOpened: This contains the name of the file last added with AddFile or
	reported with OnClick.  It can be set as well.  It will be loaded from the
	registry on initialization, so if it is non-blank, your application can load
	it again.

	Product: Used for the top-level registry key under Software.  Defaults
	to the application name.

	Company: Optional.

	RelativePath: Optional place to put the information under the application's
	key.  Defaults to WindowPos\<window caption>.

	Version: Version number for the application, so position information for
	different versions is kept separate.  Defaults to "1.0a".

	Enabled: Enables and disables all the MRU menu items.
*)

interface

uses
  {$ifdef DELPHI}
	WinProcs, Messages,
  {$endif}
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
	Menus;

type
	TMruClickEvent = procedure(name: String) of Object;

	TMruMenu = class(TComponent)
	private
		{ Private declarations }
		fBeforeItem: TMenuItem;
		fAfterItem: TMenuItem;
		fOnClick: TMruClickEvent;
		fCompany: String;
		fProduct: String;
		fVersion: String;
    fEnabled: Boolean;
    fSaveState: Boolean;

		procedure SetBeforeItem(item: TMenuItem);
		procedure SetAfterItem(item: TMenuItem);

		{ These implement TMenuItem.MenuIndex for Win16. }
		function BeforeIndex: Integer;
		function AfterIndex: Integer;

		procedure SaveItemsToRegistry;
		procedure ClearAllItems;
		procedure LoadItemsFromRegistry;

		function AddNewItem(accelerator: Integer; itemName: String; index: Integer): TMenuItem;
		procedure ItemClicked(Sender: TObject);
		function StartKey: String;

		function GetLastOpened: String;
		procedure SetLastOpened(FileName: String);
    procedure SetEnabled(const Value: Boolean);
	protected
		{ Protected declarations }
	public
		{ Public declarations }
		constructor Create(AOwner: TComponent); override;
		procedure AddFile(FileName: String);
		procedure Clear;
			{ ClearAllItems(); }
		property LastOpened: String read GetLastOpened write SetLastOpened;
	published
		{ Published declarations }
		property BeforeItem: TMenuItem read fBeforeItem write SetBeforeItem;
		property AfterItem: TMenuItem read fAfterItem write SetAfterItem;
		property OnClick: TMruClickEvent read fOnClick write fOnClick;
		property Company: String read fCompany write fCompany;
		property Product: String read fProduct write fProduct;
		property Version: String read fVersion write fVersion;
		property Enabled: Boolean read fEnabled write SetEnabled default true;
		property SaveState: Boolean read fSaveState write fSaveState default true;
	end;

procedure Register;

implementation

uses
{$ifdef win32}
	Registry,
{$else}
	IniFiles,
{$endif}
	CType, TjwStrUtil;

const
	MainKey = 'MRU Files';
	LastOpenedKey = 'Last Opened';

procedure Register;
begin
	RegisterComponents('TJW', [TMruMenu]);
end;

{$ifndef win32}
function FindMenuIndex(item: TMenuItem): Integer;
var
	i: Integer;
begin
	Result := -1;
	for i := 0 to item.Parent.Count - 1 do
		if item.Parent.Items[i] = item then begin
			Result := i;
			Break;
		end;
end;
{$endif}

{ Returns the integer that starts the caption string for this menu item.
	Returns -1 if there is none.
	Assumes that the number starts with a leading ampersand. }
function GetIndexVal(item: TMenuItem): Integer;
begin
	if item.Caption[1] <> '&' then
		Result := -1
	else
		Result := StrToIntDef(item.Caption[2], -1);
end;

function ItemToFileName(item: TMenuItem): String;
begin
	Result := item.Caption;

  Result := RemovePrefix(Result, '&');
	while IsNumber(Result[1]) do
    Result := DeleteFirstChar(Result);

  Result := Trim(Result);
end;

{ Replaces a leading numeric string in the item's caption with the specified
  value. }
procedure ReplaceIndexVal(item: TMenuItem; newValue: Integer);
begin
	{ add the new number, with a new ampersand. }
	item.Caption := '&' + IntToStr(newValue) + ' ' + ItemToFileName(item);
end;

constructor TMruMenu.Create(AOwner: TComponent);
begin
	inherited;

	fEnabled := true;
	fSaveState := true;
end;

procedure TMruMenu.SetBeforeItem(item: TMenuItem);
begin
	if fBeforeItem <> item then begin
		ClearAllItems;
		fBeforeItem := item;
		LoadItemsFromRegistry;
	end;
end;

procedure TMruMenu.SetAfterItem(item: TMenuItem);
begin
	if fAfterItem <> item then begin
		ClearAllItems;
		fAfterItem := item;
		LoadItemsFromRegistry;
	end;
end;

function TMruMenu.BeforeIndex: Integer;
begin
{$ifdef win32}
	Result := fBeforeItem.MenuIndex;
{$else}
	Result := FindMenuIndex(fBeforeItem);
{$endif}
end;

function TMruMenu.AfterIndex: Integer;
begin
{$ifdef win32}
	Result := fAfterItem.MenuIndex;
{$else}
	Result := FindMenuIndex(fAfterItem);
{$endif}
end;

procedure TMruMenu.SaveItemsToRegistry;
var
	parent: TMenuItem;
	iniFile: {$ifdef win32} TRegIniFile {$else} TIniFile {$endif};
	i, index: Integer;
	item: TMenuItem;
begin
	if (fBeforeItem <> nil)
		and (fAfterItem <> nil)
		and not (csDesigning in ComponentState)
		and fSaveState
	then begin
		{ assert(fBeforeItem->Parent == fAfterItem->Parent); }
		parent := fBeforeItem.Parent;

		{ open the registry }
		iniFile := {$ifdef win32} TRegIniFile {$else} TIniFile {$endif}.Create(StartKey);
		try
			{ erase existing entries }
			iniFile.EraseSection(MainKey);

			{ write current entries, indexed by their numbers }
			for i := BeforeIndex + 1 to AfterIndex - 1 do begin
				item := parent.Items[i];
				index := GetIndexVal(item);
				if index >= 0 then
					iniFile.WriteString(MainKey, IntToStr(index), ItemToFileName(item));
			end;
		finally
			iniFile.Free;
		end;
	end;
end;

procedure TMruMenu.ClearAllItems;
var
	parent, item: TMenuItem;
	i: Integer;
begin
	if (fBeforeItem <> nil)
		and (fAfterItem <> nil)
	then begin
		{ assert(fBeforeItem->Parent == fAfterItem->Parent); }
		parent := fBeforeItem.Parent;

		{ delete entries }
		for i := BeforeIndex + 1 to AfterIndex - 1 do begin
			item := parent.Items[i];
			parent.Remove(item);
			item.Free;
		end;
	end;
end;

procedure TMruMenu.LoadItemsFromRegistry;
var
	iniFile: {$ifdef win32} TRegIniFile {$else} TIniFile {$endif};
	accelerator,  { number in the list }
		index: Integer;  { index in the parent menu }
	fileName: String;
begin
	if (fBeforeItem <> nil)
		and (fAfterItem <> nil)
		and not (csDesigning in ComponentState)
	then begin
		{ open the registry }
		iniFile := {$ifdef win32} TRegIniFile {$else} TIniFile {$endif}.Create(StartKey);
		try
			{ read and insert items, indexed by their numbers }
			index := BeforeIndex + 1;  { index in the parent menu }
			{ assert(index = AfterIndex); }
			if index <> AfterIndex then
				raise Exception.Create('MRU menu items not initialized correctly');
			for accelerator := 1 to 9 do begin
				{ see if this item is in the registry }
				fileName := iniFile.ReadString(MainKey, IntToStr(accelerator), '');
				if fileName <> '' then begin
					{ add the item }
					AddNewItem(accelerator, fileName, index);
					Inc(index);
				end;
			end;

			{ add the separator at the end, if there were any items. }
			if index > BeforeIndex + 1 then
				AddNewItem(-1, '-', AfterIndex);
		finally
			iniFile.Free;
		end;
	end;
end;

{ If accelerator is less than zero, just uses the given name; otherwise, }
{ constructs a name with the appropriate accelerator. }
function TMruMenu.AddNewItem(accelerator: Integer; itemName: String;
	index: Integer): TMenuItem;
begin
	{ assert(fBeforeItem); }

	Result := TMenuItem.Create(fBeforeItem.Owner);
	if accelerator >= 0 then begin
		Result.Caption := '&' + IntToStr(accelerator) + ' ' + itemName;
		Result.OnClick := ItemClicked;
		Result.Hint := 'Open this file';
	end else
		Result.Caption := itemName;

	fBeforeItem.Parent.Insert(index, Result);
end;

procedure TMruMenu.ItemClicked(Sender: TObject);
var
	FileName: String;
begin
	if Assigned(fOnClick) then begin
		FileName := ItemToFileName(Sender as TMenuItem);
		fOnClick(FileName);
		SetLastOpened(FileName);
	end;
end;

function TMruMenu.StartKey: String;
begin
{$ifdef win32}
	Result := 'Software\';

	if fCompany <> '' then
		Result := Result + fCompany + '\';

	if fProduct <> '' then
		Result := Result + fProduct + '\'
	else
		Result := Result + Application.Title + '\';

	if fVersion <> '' then
		Result := Result + fVersion + '\'
	else
		Result := Result + fVersion + 'v1.0a\';
{$else}
	Result := fProduct + '.ini';
{$endif}
end;

procedure TMruMenu.AddFile(FileName: String);
var
	parent, item, newItem: TMenuItem;
	accelerator, i, currentVal: Integer;
begin
	{ assert(fBeforeItem); }
	{ assert(fAfterItem); }
	{ assert(fBeforeItem->Parent == fAfterItem->Parent); }
	parent := fBeforeItem.Parent;

	{ expand the file path. }
	FileName := ExpandFileName(FileName);

	{ insert a new item with index 1 for this name }
	newItem := AddNewItem(1, FileName, BeforeIndex + 1);

	{ renumber the items in the file menu. }
	{ remove any with numbers greater than 9. }
	{ also remove any with the same name as this one. }
	accelerator := 1;
	i := BeforeIndex + 2;
	while i < AfterIndex do begin
		item := parent.Items[i];
		currentVal := GetIndexVal(item);
		if currentVal >= 0 then begin { valid menu item? }
			if (accelerator >= 9)  { aged out? }
				or (ItemToFileName(item) = ItemToFileName(newItem))  { same name? }
			then begin
				{ remove it from the menu. }
				parent.Remove(item);
				item.Free;
			end else begin
				{ replace its accelerator. }
				ReplaceIndexVal(item, accelerator);
				Inc(accelerator);
				Inc(i);
			end;
		end else
			Inc(i);
	end;

	{ ensure that there's a separator before afterItem }
	if parent.Items[AfterIndex - 1].Caption <> '-' then
		AddNewItem(-1, '-', AfterIndex);

	{ save the list }
	SaveItemsToRegistry;
	SetLastOpened(FileName);
end;

procedure TMruMenu.Clear;
begin
	ClearAllItems;
end;

function TMruMenu.GetLastOpened: String;
var
	iniFile: {$ifdef win32} TRegIniFile {$else} TIniFile {$endif};
begin
	{ open the registry }
	iniFile := {$ifdef win32} TRegIniFile {$else} TIniFile {$endif}.Create(StartKey);
	try
		{ read the last-opened file name }
		Result := iniFile.ReadString(MainKey, LastOpenedKey, '');
	finally
		iniFile.Free;
	end;
end;

procedure TMruMenu.SetLastOpened(FileName: String);
var
	iniFile: {$ifdef win32} TRegIniFile {$else} TIniFile {$endif};
begin
	if fSaveState then begin
		{ open the registry }
		iniFile := {$ifdef win32} TRegIniFile {$else} TIniFile {$endif}.Create(StartKey);
		try
			{ write the last-opened file name }
			iniFile.WriteString(MainKey, LastOpenedKey, FileName);
		finally
			iniFile.Free;
		end;
	end;
end;

procedure TMruMenu.SetEnabled(const Value: Boolean);
var
	i: Integer;
	parent, item: TMenuItem;
begin
	if Value <> fEnabled then begin
		fEnabled := Value;

		parent := fBeforeItem.Parent;

		for i := BeforeIndex + 1 to AfterIndex - 1 do begin
			item := parent.Items[i];
			item.Enabled := fEnabled;
		end;
	end;
end;

end.
