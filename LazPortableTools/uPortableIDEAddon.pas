{
  uPortableIDEAddon.pas - Registro do Pacote de Integração da IDE (Estilo OTA)
}
unit uPortableIDEAddon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Controls, Forms,
  MenuIntf, IDEWindowIntf, IDECommands,
  frmPortablePanel;

procedure Register;

implementation

var
  PortableCmd: TIDECommand;

procedure ShowPortablePanelExecuted(Sender: TObject);
begin
  if frmPortablePanel = nil then
    Application.CreateForm(TfrmPortablePanel, frmPortablePanel);
  frmPortablePanel.Show;
end;

procedure Register;
var
  ToolsMenu: TIDEMenuSection;
begin
  // Adiciona comando no Menu "Tools" da IDE do Lazarus
  ToolsMenu := RegisterIDEMenuSection(itmMainTools, 'PortableToolsSection');
  
  PortableCmd := RegisterIDEMenuCommand(
    ToolsMenu,
    'PortableToolsCmd',
    'Lazarus Portable Tools (Painel OTA)',
    nil,
    @ShowPortablePanelExecuted
  );
end;

end.
