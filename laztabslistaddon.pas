{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit LazTabsListAddOn;

{$warn 5023 off : no warning about unused units}
interface

uses
  LazIdeTabListForm, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('LazIdeTabListForm', @LazIdeTabListForm.Register);
end;

initialization
  RegisterPackage('LazTabsListAddOn', @Register);
end.
