{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************

 Editor tabs list - Lazarus addon
 Author: Domingo Galmés (dgalmesp@gmail.com)  20-06-2026

 Some code borrowed from
    Procedure List - Lazarus addon
    Author: Graeme Geldenhuys  (graemeg@gmail.com)

  Abstract:
  The tab list enables you to view a list of all editors open in the ide and
  quick filter by name to select the desired editor.

}
unit LazIdeTabListForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, contnrs,
  // LCL
  LCLType, Forms, Controls, Dialogs, ComCtrls, ExtCtrls, StdCtrls, Clipbrd,
  Graphics, Grids, TextTools,
  // LazUtils
  LazStringUtils,
  // Codetools
  KeywordFuncLists,
  // IDEIntf
  LazIDEIntf, IDEImagesIntf, SrcEditorIntf, IDEWindowIntf,IDECommands, MenuIntf,
  ToolBarIntf,
  // IDE
  EnvironmentOpts,
  SynEdit
  ;

type

  { TLazIdeTabListForm }
  TLazIdeTabListForm = class(TForm)
    edMethods: TEdit;
    lblSearch: TLabel;
    pnlHeader: TPanel;
    StatusBar: TStatusBar;
    SG: TStringGrid;
    TB: TToolBar;
    ToolButton2: TToolButton;
    tbJumpTo: TToolButton;
    ToolButton4: TToolButton;
    tbFilterAny: TToolButton;
    tbFilterStart: TToolButton;
    ToolButton7: TToolButton;
    ToolButton9: TToolButton;
    procedure edMethodsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure SGDblClick(Sender: TObject);
    procedure SomethingChange(Sender: TObject);
  private
    FMainFilename: string;
    FEditorsList: TFPList;
    procedure JumpToSelection;
    procedure PopulateGrid;
    function AddToGrid( pEditor: TSourceEditorInterface): boolean;
    function PassFilter(pTabName, pSearchStr: string): boolean;
    procedure ClearGrid;
  end; 

procedure Register;

procedure ExecuteIdeTabList(Sender:TObject);

implementation

{$R *.lfm}

{$R lazmaplistaddon.res}

const
  SG_COLIDX_UNIT = 0;
  SG_COLIDX_FILENAME = 1;

resourcestring
  lisPListProcedureList='Tab list';
  lisMenuSearch='Search';
  lisPListJumpToSelection='Goto unit';
  lisPListFilterAny='Filter Any';
  lisPListFilterStart='Filter Start';
  lisEditor='Unit';
  lisPListType='Filename';


{ This is where it all starts. Gets called from Lazarus. }
procedure ExecuteIdeTabList(Sender: TObject);
begin
  with TLazIdeTabListForm.Create(nil) do
  try
    ShowModal;
  finally
    Free;
  end;
end;

function FilterFits(const SubStr, Str: string): boolean;
var
  Src: pchar;
  PFilter: pchar;
  c: char;
  i: integer;
begin
  Result := SubStr = '';
  if Result then
    Exit(True);
  Src := PChar(Str);
  PFilter := PChar(SubStr);
  repeat
    c := Src^;
    if c <> #0 then
    begin
      if UpChars[Src^] = UpChars[PFilter^] then
      begin
        i := 1;
        while (UpChars[Src[i]] = UpChars[PFilter[i]]) and not (PFilter[i] = #0) do
          Inc(i);
        if PFilter[i] = #0 then
          exit(True);
      end;
    end
    else
      exit(False);
    Inc(Src);
  until False;
end;

{ TLazIdeTabListForm }

function SortEditorsByName(Item1, Item2: Pointer): Integer;
begin
  result:=AnsiCompareText(TSourceEditorInterface(Item1).PageName,TSourceEditorInterface(Item2).PageName  );
end;

procedure TLazIdeTabListForm.FormCreate(Sender: TObject);
var
  i: integer;
begin
  // assign resource strings to Captions and Hints
  Caption            := lisPListProcedureList;
  lblSearch.Caption  := lisMenuSearch;
  tbJumpTo.Hint      := lisPListJumpToSelection;
  tbFilterAny.Hint   := lisPListFilterAny;
  tbFilterStart.Hint := lisPListFilterStart;
  SG.Columns[SG_COLIDX_UNIT].Title.Caption := lisEditor;
  SG.Columns[SG_COLIDX_FILENAME     ].Title.Caption := lisPListType;

  // assign resource images to toolbuttons
  TB.Images := IDEImages.Images_16;
  tbJumpTo.ImageIndex      := IDEImages.LoadImage('menu_goto_line');
  tbFilterAny.ImageIndex   := IDEImages.LoadImage('filter_any_place');
  tbFilterStart.ImageIndex := IDEImages.LoadImage('filter_from_begin');

  SG.FocusRectVisible := false;

  if SourceEditorManagerIntf.ActiveEditor = nil then Exit; //==>

  FMainFilename := SourceEditorManagerIntf.ActiveEditor.Filename;
  Caption := Caption + ' - ' + ExtractFileName(FMainFilename);
  StatusBar.Panels[0].Text := '';
  //todo: read options.
  //tbFilterStart.Down := EnvironmentOptions.ProcedureListFilterStart;
  tbFilterStart.Down := False;
  IDEDialogLayoutList.ApplyLayout(Self, 950, 680);
  FEditorsList := TFPList.Create;
  FEditorsList.Capacity:=SourceEditorManagerIntf.SourceEditorCount;

  i:=0;
  while i< SourceEditorManagerIntf.SourceEditorCount do
  begin
    FEditorsList.Add(Pointer(SourceEditorManagerIntf.SourceEditors[i]));
    inc(i);
  end;
  FEditorsList.Sort(@SortEditorsByName);
  PopulateGrid;
end;

procedure TLazIdeTabListForm.edMethodsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  c: char;
begin
  if KeyToQWERTY(Key, Shift, c) then
    edMethods.SelText := c;
end;

procedure TLazIdeTabListForm.FormDestroy(Sender: TObject);
begin
  //todo: save options.
  //EnvironmentOptions.ProcedureListFilterStart := tbFilterStart.Down;
  ClearGrid;
  IDEDialogLayoutList.SaveLayout(Self);
  FreeAndNil(FEditorsList);
end;

procedure TLazIdeTabListForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Shift = [] then
  begin
    case Key of

    { Form }
    VK_RETURN : begin
        JumpToSelection;
        Key := 0;
      end;
    VK_ESCAPE : begin
        Key := 0;
        ModalResult := mrCancel;
      end;

    { Arrows }
    VK_DOWN : begin

        if SG.Row < SG.FixedRows then // if (Row = -1) or (Row < FixedRows)
        begin
          if SG.RowCount > SG.FixedRows then
            SG.Row := SG.FixedRows;
        end else begin
          if (SG.Row + 1) < SG.RowCount then
            SG.Row := SG.Row + 1;
        end;
        Key := 0;
      end;
    VK_UP : begin

        if SG.Row < SG.FixedRows then // if (Row = -1) or (Row < FixedRows)
        begin
          if SG.RowCount > SG.FixedRows then
            SG.Row := SG.RowCount - 1;
        end else begin
          if SG.Row > SG.FixedRows then
            SG.Row := SG.Row - 1;
        end;
        Key := 0;
      end;

    { PageUp and PageDown }
    VK_NEXT : begin
        if SG.Row < SG.FixedRows then // if (Row = -1) or (Row < FixedRows)
        begin
          if SG.RowCount > SG.FixedRows then
            SG.Row := SG.FixedRows;
        end else begin
          SG.Row := Min(SG.RowCount - 1, SG.Row + (SG.VisibleRowCount - 1));
        end;
        Key := 0;
      end;
    VK_PRIOR : begin
        if SG.Row < SG.FixedRows then // if (Row = -1) or (Row < FixedRows)
        begin
          if SG.Row > SG.FixedRows then
            SG.Row := SG.Row - 1;
        end else begin
          SG.Row := Max(SG.FixedRows, SG.Row - (SG.VisibleRowCount - 1));
        end;
        Key := 0;
      end;

    end;  // case
  end;  // if Shift = []

  if Shift = [ssCtrl] then
  begin
    case Key of

    { Home and End }
    VK_HOME : begin
        if SG.RowCount > SG.FixedRows then
          SG.Row := SG.FixedRows;
        Key := 0;
      end;
    VK_END : begin
        if SG.RowCount > SG.FixedRows then
          SG.Row := SG.RowCount - 1;
        Key := 0;
      end;

    { Scroll one line }
    VK_DOWN : begin
        if SG.RowCount > SG.FixedRows then
          SG.TopRow := Max(SG.FixedRows, Min(SG.RowCount - 1, SG.TopRow + 1));
        Key := 0;
      end;
    VK_UP : begin
        if SG.RowCount > SG.FixedRows then
          SG.TopRow := Max(SG.FixedRows, Min(SG.RowCount - 1, SG.TopRow - 1));
        Key := 0;
      end;
    end;  // case
  end;  // if Shift = [ssCtrl]
end;

procedure TLazIdeTabListForm.FormResize(Sender: TObject);
begin
  StatusBar.Panels[0].Width := ClientWidth - 105;
end;

procedure TLazIdeTabListForm.FormShow(Sender: TObject);
begin
  edMethods.SetFocus;
end;

procedure TLazIdeTabListForm.SGDblClick(Sender: TObject);
begin
  JumpToSelection;
end;

procedure ReturnFocusToEditor;
var
  wSourceEditor:TSourceEditorInterface;
  wSynEdit:TSynEdit;
begin
  wSourceEditor := TSourceEditorInterface(SourceEditorManagerIntf.ActiveEditor);
  if (wSourceEditor <> nil) and (wSourceEditor.EditorControl is TSynEdit) then
  begin
    if IDETabMaster<>nil then
      IDETabMaster.ShowCode(wSourceEditor);
    wSynEdit := TSynEdit(wSourceEditor.EditorControl);
    if wSynEdit.CanSetFocus then
      wSynEdit.SetFocus;
  end;
end;

procedure TLazIdeTabListForm.JumpToSelection;
var
  lEditor: TSourceEditorInterface;
begin
  if SG.Row < SG.FixedRows then
    Exit;
  if SG.Row > 0 then
  begin
    lEditor :=  TSourceEditorInterface(SG.Rows[SG.Row].Objects[0]);
    if lEditor <> nil then
    begin
      SourceEditorManagerIntf.ActiveEditor := lEditor;
      ReturnFocusToEditor;
    end;
  end;
  { This should close the form }
  ModalResult := mrOK;
end;

procedure TLazIdeTabListForm.PopulateGrid;
var
  lShown, lTotal: integer;
  i:integer;
  wSourceEditor: TSourceEditorInterface;
begin
  lShown := 0;
  lTotal := 0;
  SG.BeginUpdate;
  try
    ClearGrid;
    i:=0;
    while i < FEditorsList.Count do
    begin
      inc(lTotal);
      wSourceEditor := TSourceEditorInterface(FEditorsList.Items[i]);
      if wSourceEditor <> nil then
      begin
        if AddToGrid(wSourceEditor) then
          inc(lShown);
       end;
      inc(i);
    end;
  finally
    if SG.RowCount > SG.FixedRows then
      SG.Row := SG.FixedRows;
    SG.EndUpdate;
    StatusBar.Panels[1].Text := inttostr(lShown) + ' / ' + inttostr(lTotal);
  end;
end;

function TLazIdeTabListForm.AddToGrid(pEditor:TSourceEditorInterface): boolean;
var
  lNodeText: string;
  lRowIdx: Integer;
begin
  result := false;
  lNodeText := pEditor.PageName;
  { Must we add this pNode or not? }
  if not PassFilter( lNodeText, edMethods.Text) then
    Exit;
  { Add new row }
  lRowIdx := SG.RowCount;
  SG.RowCount := lRowIdx + 1;
  SG.Rows[lRowIdx].Objects[0] := pEditor;
  { procedure name }
  SG.Cells[SG_COLIDX_UNIT,lRowIdx] := lNodeText;
  SG.Cells[SG_COLIDX_FILENAME,lRowIdx] := pEditor.FileName;
  result := true;
end;

{ Do we pass all the filter tests to continue? }
function TLazIdeTabListForm.PassFilter(pTabName, pSearchStr: string): boolean;
begin
  if (Length(pSearchStr) = 0) then
    Exit(True);
  if tbFilterStart.Down then
    Result := LazStartsText(pSearchStr, pTabName)
  else
    Result := FilterFits(pSearchStr, pTabName)
end;

procedure TLazIdeTabListForm.ClearGrid;
begin
  SG.RowCount := SG.FixedRows;
end;

procedure TLazIdeTabListForm.SomethingChange(Sender: TObject);
begin
  PopulateGrid;
end;

procedure Register;
const
  SLazIdeTabList='Editor tab list';
  NAME='ViewTabList';
var
  CmdCatViewMenu: TIDECommandCategory;
  ViewlazIdeTabListCommand: TIDECommand;
  MenuItemCaption: string;
begin
  // register shortcut and menu item
  MenuItemCaption := SLazIdeTabList;
  // search shortcut category
  CmdCatViewMenu := IDECommandList.FindCategoryByName(CommandCategoryViewName);
  // register shortcut
  ViewlazIdeTabListCommand := RegisterIDECommand(CmdCatViewMenu, NAME,
    MenuItemCaption, IDEShortCut(VK_UNKNOWN, []), // <- set here your default shortcut
    CleanIDEShortCut, nil, @ExecuteIdeTabList);
  // register menu item in View menu
  RegisterIDEMenuCommand(itmViewMainWindows, NAME,
      MenuItemCaption, nil, nil, ViewlazIdeTabListCommand, 'lazmaplist');
  // register toolbar button
  RegisterIDEButtonCommand(ViewlazIdeTabListCommand);
  // register in editor tab popup menu.
  RegisterIDEMenuCommand(SourceTabMenuRoot, 'ViewTabListEdTab',
    MenuItemCaption,nil, nil, ViewlazIdeTabListCommand, 'lazmaplist');
end;

end.
