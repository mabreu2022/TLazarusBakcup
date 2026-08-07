{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit LazPortableTools;

{$warn 5023 off : no warning about unused units}
interface

uses
  uPortableIDEAddon, frmPortablePanel, uSharedPatcher, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uPortableIDEAddon', @uPortableIDEAddon.Register);
end;

initialization
  RegisterPackage('LazPortableTools', @Register);
end.
