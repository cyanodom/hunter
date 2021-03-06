-- Copyright (c) 2019-2020 Bartek thindil Jasicki <thindil@laeran.pl>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada; use Tcl.Ada;
with Tcl.MsgCat.Ada; use Tcl.MsgCat.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Preferences; use Preferences;
with RefreshData; use RefreshData;
with ShowItems; use ShowItems;
with Utils; use Utils;

package body CreateItems is

   -- ****o* CreateItems/CreateItems.Show_Create_Command
   -- FUNCTION
   -- Show text entry to enter a name of the new item
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ShowCreate itemtype
   -- Itemtype is an item type which will be created. Can be file or directory
   -- SOURCE
   function Show_Create_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Show_Create_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Frame: constant Ttk_Frame := Get_Widget(".mainframe.textframe", Interp);
      Button: Ttk_Button := Get_Widget(Frame & ".closebutton", Interp);
      TextEntry: constant Ttk_Entry :=
        Get_Widget(Frame & ".textentry", Interp);
   begin
      Tcl.Tk.Ada.Grid.Grid(Button);
      Button.Name := New_String(Frame & ".okbutton");
      configure(Button, "-command {Create " & CArgv.Arg(Argv, 1) & "}");
      Add
        (Button,
         Mc(Interp, "{Create a new}") & " " & Mc(Interp, CArgv.Arg(Argv, 1)) &
         Mc(Interp, "{ with the selected name.}"));
      Add
        (TextEntry,
         Mc(Interp, "{Enter a name for the newly created}") & " " &
         Mc(Interp, CArgv.Arg(Argv, 1)) & ".");
      Tcl.Tk.Ada.Grid.Grid(Button);
      Unbind(TextEntry, "<KeyRelease>");
      Focus(TextEntry);
      Tcl.Tk.Ada.Grid.Grid(Frame, "-row 1 -columnspan 2 -sticky we");
      if CArgv.Arg(Argv, 1) = "file" then
         NewAction := CREATEFILE;
      elsif CArgv.Arg(Argv, 1) = "directory" then
         NewAction := CREATEDIRECTORY;
      else
         NewAction := CREATELINK;
         ShowDestination;
      end if;
      ToggleToolButtons(NewAction);
      return TCL_OK;
   end Show_Create_Command;

   -- ****o* CreateItems/CreateItems.Create_Command
   -- FUNCTION
   -- Show text entry to enter a name of the new item
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Create itemtype
   -- Itemtype is an item type which will be created. Can be file or directory
   -- SOURCE
   function Create_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Create_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      TextEntry: constant Ttk_Entry :=
        Get_Widget(".mainframe.textframe.textentry", Interp);
      NewItemName, ActionString, ActionBlocker, Destination: Unbounded_String;
      Button: constant Ttk_Button :=
        Get_Widget(".mainframe.textframe.closebutton", Interp);
      File: File_Descriptor;
      DirectoryView: constant Ttk_Tree_View :=
        Get_Widget(".mainframe.paned.previewframe.directorytree", Interp);
      Hunter_Create_Exception: exception;
   begin
      NewItemName := CurrentDirectory & "/" & Get(TextEntry);
      if Exists(To_String(NewItemName)) or
        Is_Symbolic_Link(To_String(NewItemName)) then
         ActionString :=
           To_Unbounded_String
             (Mc(Interp, "{create}") & " " & CArgv.Arg(Argv, 1) & " " &
              Mc(Interp, "{with}"));
         if Is_Directory(To_String(NewItemName)) then
            ActionBlocker := To_Unbounded_String(Mc(Interp, "directory"));
         else
            ActionBlocker := To_Unbounded_String(Mc(Interp, "file"));
         end if;
         ShowMessage
           (Mc(Interp, "{You can't}") & " " & To_String(ActionString) & " " &
            Mc(Interp, "{name'}") & " " & To_String(NewItemName) & " " &
            Mc(Interp, "{'because there exists}") & " " &
            To_String(ActionBlocker) & " " & Mc(Interp, "{with that name.}"));
         goto End_Of_Create;
      end if;
      if not Is_Write_Accessible_File
          (Containing_Directory(To_String(NewItemName))) then
         ShowMessage
           (Mc(Interp, "{You don't have permissions to write to}") & " " &
            Containing_Directory(To_String(NewItemName)));
         goto End_Of_Create;
      end if;
      case NewAction is
         when CREATEDIRECTORY =>
            Create_Path(To_String(NewItemName));
         when CREATEFILE =>
            Create_Path(Containing_Directory(To_String(NewItemName)));
            File := Create_File(To_String(NewItemName), Binary);
            Close(File);
         when CREATELINK =>
            Destination := DestinationDirectory;
            if Selection(DirectoryView)'Length > 0 then
               Destination :=
                 DestinationDirectory &
                 SecondItemsList(Positive'Value(Selection(DirectoryView)))
                   .Name;
            end if;
            Tcl_Eval
              (Interp,
               "file link -symbolic {" & To_String(NewItemName) & "} {" &
               To_String(Destination) & "}");
         when others =>
            raise Hunter_Create_Exception
              with Mc(Interp, "{Invalid action type}");
      end case;
      if not Settings.StayInOld and then NewAction /= CREATELINK then
         CurrentDirectory :=
           To_Unbounded_String(Containing_Directory(To_String(NewItemName)));
      end if;
      LoadDirectory(To_String(CurrentDirectory));
      UpdateWatch(To_String(CurrentDirectory));
      UpdateDirectoryList(True);
      <<End_Of_Create>>
      if Invoke(Button) /= "" then
         return TCL_ERROR;
      end if;
      ToggleToolButtons(NewAction, True);
      return TCL_OK;
   end Create_Command;

   procedure CreateCreateUI is
   begin
      AddCommand("ShowCreate", Show_Create_Command'Access);
      AddCommand("Create", Create_Command'Access);
   end CreateCreateUI;

end CreateItems;
