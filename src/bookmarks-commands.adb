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
with Ada.Environment_Variables; use Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Text_IO.Unbounded_IO; use Ada.Text_IO.Unbounded_IO;
with Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with CArgv;
with Tcl; use Tcl;
with Tcl.MsgCat.Ada; use Tcl.MsgCat.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid; use Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkEntry; use Tcl.Tk.Ada.Widgets.TtkEntry;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Modules; use Modules;
with RefreshData; use RefreshData;
with Utils; use Utils;

package body Bookmarks.Commands is

   -- ****o* Commands/Commands.GoToBookmark_Command
   -- FUNCTION
   -- Go to the selected bookmarked directory
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- GoToBookmark path
   -- Path is the full path to the directory which will be set as current
   -- directory (and show to the user)
   -- SOURCE
   function GoToBookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function GoToBookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc);
   begin
      if NewAction /= MOVE then
         if NewAction = CLEARTRASH then
            NewAction := SHOWTRASH;
         end if;
         if NewAction = SHOWTRASH then
            ToggleToolButtons(NewAction, True);
         end if;
         NewAction := COPY;
      end if;
      CurrentDirectory :=
        To_Unbounded_String(Normalize_Pathname(CArgv.Arg(Argv, 1)));
      LoadDirectory(To_String(CurrentDirectory));
      UpdateDirectoryList(True);
      Execute_Modules(On_Enter, "{" & To_String(CurrentDirectory) & "}");
      return TCL_OK;
   end GoToBookmark_Command;

   -- ****if* Commands/Commands.UpdateNewAction
   -- FUNCTION
   -- Update NewAction and toolbars if needed
   -- SOURCE
   procedure UpdateNewAction is
      -- ****
   begin
      if NewAction /= MOVE then
         if NewAction = SHOWTRASH then
            ToggleToolButtons(NewAction, True);
         end if;
         NewAction := COPY;
      end if;
   end UpdateNewAction;

   -- ****o* Commands/Commands.SetDestination_Command
   -- FUNCTION
   -- Show text entry to enter directory destination
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- SetDestination
   -- SOURCE
   function SetDestination_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function SetDestination_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      TextFrame: constant Ttk_Frame :=
        Get_Widget(".mainframe.textframe", Interp);
      Button: Ttk_Button := Get_Widget(TextFrame & ".okbutton", Interp);
      TextEntry: constant Ttk_Entry :=
        Get_Widget(TextFrame & ".textentry", Interp);
   begin
      UpdateNewAction;
      configure(Button, "-command GoToDestination");
      Add(Button, Mc(Interp, "{Go to the selected destination}"));
      Focus(TextEntry);
      Insert(TextEntry, "0", To_String(CurrentDirectory));
      Add(TextEntry, Mc(Interp, "{Enter the selected destination}"));
      Unbind(TextEntry, "<KeyRelease>");
      Tcl.Tk.Ada.Grid.Grid(Button);
      Button.Name := New_String(".mainframe.textframe.closebutton");
      Tcl.Tk.Ada.Grid.Grid(Button);
      Tcl.Tk.Ada.Grid.Grid(TextFrame, "-row 1 -columnspan 2 -sticky we");
      return TCL_OK;
   end SetDestination_Command;

   -- ****o* Commands/Commands.GoToDestination_Command
   -- FUNCTION
   -- Go to the destination directory selected by the user
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed.
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- GoToDestination
   -- SOURCE
   function GoToDestination_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function GoToDestination_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      TextEntry: constant Ttk_Entry :=
        Get_Widget(".mainframe.textframe.textentry", Interp);
      HideButton: constant Ttk_Button :=
        Get_Widget(".mainframe.textframe.closebutton", Interp);
   begin
      UpdateNewAction;
      if not Ada.Directories.Exists(Get(TextEntry)) then
         ShowMessage
           (Mc(Interp, "{Directory}") & " '" & Get(TextEntry) & "' " &
            Mc(Interp, "{doesn't exists.}"));
         return TCL_OK;
      end if;
      CurrentDirectory := To_Unbounded_String(Get(TextEntry));
      if Invoke(HideButton) /= "" then
         return TCL_ERROR;
      end if;
      LoadDirectory(To_String(CurrentDirectory));
      UpdateDirectoryList(True);
      UpdateWatch(To_String(CurrentDirectory));
      return TCL_OK;
   end GoToDestination_Command;

   -- ****o* Commands/Commands.Add_Bookmark_Command
   -- FUNCTION
   -- Add the bookmark to the selected directory
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command. Unused
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- AddBookmark
   -- SOURCE
   function Add_Bookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Add_Bookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
      File: File_Type;
   begin
      if Ada.Directories.Exists
          (Value("HOME") & "/.config/gtk-3.0/bookmarks") then
         Open(File, Append_File, Value("HOME") & "/.config/gtk-3.0/bookmarks");
      else
         Create
           (File, Append_File, Value("HOME") & "/.config/gtk-3.0/bookmarks");
      end if;
      Put_Line(File, "file://" & CurrentSelected);
      Close(File);
      CreateBookmarkMenu;
      SetBookmarkButton;
      return TCL_OK;
   end Add_Bookmark_Command;

   -- ****o* Commands/Commands.Remove_Bookmark_Command
   -- FUNCTION
   -- Remove the bookmark to the selected directory
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- RemoveBookmark
   -- SOURCE
   function Remove_Bookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Remove_Bookmark_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
      NewFile, OldFile: File_Type;
      Line, Path: Unbounded_String;
      Added: Boolean := False;
   begin
      Rename
        (Value("HOME") & "/.config/gtk-3.0/bookmarks",
         Value("HOME") & "/.config/gtk-3.0/bookmarks.old");
      Open(OldFile, In_File, Value("HOME") & "/.config/gtk-3.0/bookmarks.old");
      Create(NewFile, Out_File, Value("HOME") & "/.config/gtk-3.0/bookmarks");
      while not End_Of_File(OldFile) loop
         Line := Get_Line(OldFile);
         if Length(Line) > 7 and then Slice(Line, 1, 7) = "file://" then
            Path := Unbounded_Slice(Line, 8, Length(Line));
            if Path /= CurrentSelected then
               Put_Line(NewFile, Line);
               Added := True;
            end if;
         end if;
      end loop;
      Close(NewFile);
      Close(OldFile);
      Delete_File(Value("HOME") & "/.config/gtk-3.0/bookmarks.old");
      if not Added then
         Delete_File(Value("HOME") & "/.config/gtk-3.0/bookmarks");
      end if;
      CreateBookmarkMenu;
      SetBookmarkButton;
      return TCL_OK;
   end Remove_Bookmark_Command;

   procedure AddCommands is
   begin
      AddCommand("GoToBookmark", GoToBookmark_Command'Access);
      AddCommand("SetDestination", SetDestination_Command'Access);
      AddCommand("GoToDestination", GoToDestination_Command'Access);
      AddCommand("AddBookmark", Add_Bookmark_Command'Access);
      AddCommand("RemoveBookmark", Remove_Bookmark_Command'Access);
   end AddCommands;

end Bookmarks.Commands;
