{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit tjw;

interface

uses
  MruMenu, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('MruMenu', @MruMenu.Register);
end;

initialization
  RegisterPackage('tjw', @Register);
end.
