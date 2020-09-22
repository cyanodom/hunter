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
with Tcl.MsgCat.Ada; use Tcl.MsgCat.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkWidget; use Tcl.Tk.Ada.Widgets.TtkWidget;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Preferences; use Preferences;
with RefreshData; use RefreshData;
with Utils; use Utils;

package body ActivateItems is

   -- ****if* ActivateItems/ExecuteFile
   -- FUNCTION
   -- Execute the selected file
   -- PARAMETERS
   -- FileName  - Name of file (full path) which will be executed
   -- Arguments - Additional arguments passed to the file
   -- RESULT
   -- Spawned process ID of the executed file. If the file cannot
   -- be executed, return Invalid_Pid
   -- SOURCE
   function ExecuteFile
     (FileName, Arguments: String) return GNAT.OS_Lib.Process_Id is
      -- ****
      Pid: GNAT.OS_Lib.Process_Id;
   begin
      Pid :=
        Non_Blocking_Spawn
          (Full_Name(FileName), Argument_String_To_List(Arguments).all);
      if Pid /= GNAT.OS_Lib.Invalid_Pid then
         Lower(Get_Main_Window(Get_Context));
      end if;
      return Pid;
   end ExecuteFile;

   -- ****o* ActivateItems/Activate_Item_Command
   -- FUNCTION
   -- "Activate" selected file or directory. Action depends on what selected
   -- item is. For example: it go to selected directory, opens text files in
   -- editor and so on.
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.a Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ActivateItem
   -- SOURCE
   function Activate_Item_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Activate_Item_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
   begin
      if Is_Directory(To_String(CurrentSelected)) then
         if not Is_Read_Accessible_File(To_String(CurrentSelected)) then
            ShowMessage(Mc(Interp, "{You can't enter this directory.}"));
            return TCL_OK;
         end if;
         CurrentDirectory := CurrentSelected;
         if Settings.ShowPreview then
            ItemsList := SecondItemsList;
         else
            LoadDirectory(To_String(CurrentDirectory));
         end if;
         UpdateDirectoryList(True);
         UpdateWatch(To_String(CurrentDirectory));
      else
         declare
            MimeType: constant String :=
              GetMimeType(To_String(CurrentSelected));
            Pid: GNAT.OS_Lib.Process_Id;
            Openable: Boolean := CanBeOpened(MimeType);
            ExecutableName: constant String := FindExecutable("xdg-open");
         begin
            if MimeType(1 .. 4) = "text" and not Openable then
               Openable := CanBeOpened("text/plain");
            end if;
            if not Openable then
               if not Is_Executable_File(To_String(CurrentSelected)) then
                  ShowMessage
                    (Mc
                       (Interp,
                        "{I can't open this file. No application associated with this type of files.}"));
                  return TCL_OK;
               end if;
               Pid := ExecuteFile(To_String(CurrentSelected), "");
               if Pid = GNAT.OS_Lib.Invalid_Pid then
                  ShowMessage("I can't execute this file.");
               end if;
            else
               if ExecutableName = "" then
                  return TCL_OK;
               end if;
               Pid := ExecuteFile(ExecutableName, To_String(CurrentSelected));
            end if;
            if Pid = GNAT.OS_Lib.Invalid_Pid then
               ShowMessage
                 (Mc
                    (Interp,
                     "{I can't open this file. Can't start application asociated with this type of files.}"));
            end if;
         end;
      end if;
      return TCL_OK;
   end Activate_Item_Command;

   -- ****o* ActivateItems/Toggle_Execute_With_Command
   -- FUNCTION
   -- Show text entry to enter with what program execute selected file or
   -- directory
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ToggleExecuteWith
   -- SOURCE
   function Toggle_Execute_With_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Toggle_Execute_With_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      TextFrame: Ttk_Frame;
      Button: Ttk_Button;
      TextEntry: Ttk_Entry;
      Hunter_Activate_Item_Exception: exception;
   begin
      TextEntry.Interp := Interp;
      TextEntry.Name := New_String(".mainframe.textframe.textentry");
      Button.Interp := Interp;
      Button.Name := New_String(".mainframe.textframe.closebutton");
      if Winfo_Get(TextEntry, "ismapped") = "0" then
         Tcl.Tk.Ada.Grid.Grid(Button);
         Button.Name := New_String(".mainframe.textframe.okbutton");
         configure(Button, "-command ExecuteWith");
         Add
           (Button,
            Mc
              (Interp,
               "{Execute the selected file or directory with the entered program.}"));
         Tcl.Tk.Ada.Grid.Grid(Button);
         Button.Name :=
           New_String(".mainframe.toolbars.itemtoolbar.openwithbutton");
         State(Button, "selected");
         Add
           (TextEntry,
            Mc(Interp, "{Enter command to use to open selected item.}"));
         Unbind(TextEntry, "<KeyRelease>");
         Focus(TextEntry);
         TextFrame.Interp := Interp;
         TextFrame.Name := New_String(".mainframe.textframe");
         Tcl.Tk.Ada.Grid.Grid(TextFrame, "-row 1 -columnspan 2 -sticky we");
      else
         if Invoke(Button) /= "" then
            raise Hunter_Activate_Item_Exception
              with Mc(Interp, "{Can't hide execute program bar}");
         end if;
         Button.Name :=
           New_String(".mainframe.toolbars.itemtoolbar.openwithbutton");
         State(Button, "!selected");
      end if;
      return TCL_OK;
   end Toggle_Execute_With_Command;

   -- ****o* ActivateItems/Execute_With_Command
   -- FUNCTION
   -- Execute the selected file or directory with the selected command
   -- entered by an user
   -- PARAMETERS
   -- ClientData - Custom data send to the command.
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command.
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK;
   -- COMMANDS
   -- ExecuteWith
   -- SOURCE
   function Execute_With_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Execute_With_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      TextEntry: Ttk_Entry;
      Value, CommandName: Unbounded_String;
      Pid: GNAT.OS_Lib.Process_Id;
      SpaceIndex: Natural;
      Arguments: Argument_List_Access;
   begin
      TextEntry.Interp := Interp;
      TextEntry.Name := New_String(".mainframe.textframe.textentry");
      Value := To_Unbounded_String(Get(TextEntry));
      if Value = Null_Unbounded_String then
         return TCL_OK;
      end if;
      SpaceIndex := Index(Value, " ");
      CommandName :=
        (if SpaceIndex > 0 then Unbounded_Slice(Value, 1, SpaceIndex - 1)
         else Value);
      CommandName :=
        To_Unbounded_String(FindExecutable(To_String(CommandName)));
      if CommandName = Null_Unbounded_String then
         ShowMessage
           (Mc(Interp, "{Can't find command:}") & " " &
            Slice(Value, 1, SpaceIndex));
         return TCL_OK;
      end if;
      Arguments :=
        (if SpaceIndex > 0 then
           Argument_String_To_List
             (Slice(Value, SpaceIndex, Length(Value)) & " @2")
         else Argument_String_To_List("@2"));
      for I in Arguments'Range loop
         if Arguments(I).all = "@2" then
            Arguments(I) := new String'(To_String(CurrentSelected));
         end if;
      end loop;
      Pid :=
        Non_Blocking_Spawn(Full_Name(To_String(CommandName)), Arguments.all);
      if Pid = GNAT.OS_Lib.Invalid_Pid then
         ShowMessage(Mc(Interp, "{Can't execute this command}"));
         return TCL_OK;
      else
         Lower(Get_Main_Window(Get_Context));
      end if;
      return Toggle_Execute_With_Command(ClientData, Interp, Argc, Argv);
   end Execute_With_Command;

   -- ****o* ActivateItems/Execute_Command
   -- FUNCTION
   -- Execute the selected file or directory
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- Execute
   -- SOURCE
   function Execute_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Execute_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      Pid: GNAT.OS_Lib.Process_Id;
   begin
      Pid := ExecuteFile(To_String(CurrentSelected), "");
      if Pid = GNAT.OS_Lib.Invalid_Pid then
         ShowMessage(Mc(Interp, "{Can't execute this command}"));
      end if;
      return TCL_OK;
   end Execute_Command;

   procedure CreateActivateUI is
   begin
      AddCommand("ActivateItem", Activate_Item_Command'Access);
      AddCommand("ToggleExecuteWith", Toggle_Execute_With_Command'Access);
      AddCommand("ExecuteWith", Execute_With_Command'Access);
      AddCommand("Execute", Execute_Command'Access);
   end CreateActivateUI;

end ActivateItems;
