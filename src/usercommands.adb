-- Copyright (c) 2020 Bartek thindil Jasicki <thindil@laeran.pl>
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

with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Directories; use Ada.Directories;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.Expect; use GNAT.Expect;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.String_Split; use GNAT.String_Split;
with CArgv;
with Tcl; use Tcl;
with Tcl.MsgCat.Ada; use Tcl.MsgCat.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Image.Photo; use Tcl.Tk.Ada.Image.Photo;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tklib.Ada.Tooltip; use Tcl.Tklib.Ada.Tooltip;
with MainWindow; use MainWindow;
with Messages; use Messages;
with ShowItems; use ShowItems;
with Utils; use Utils;

package body UserCommands is

   procedure UpdateUserCommandsList is
      Row: Positive := 1;
      Label: Ttk_Label;
      CommandsFrame: constant Ttk_Frame :=
        Get_Widget(".preferencesframe.canvas.notebook.actions.commandsframe");
      Item: Ttk_Frame;
      Tokens: Slice_Set;
      Image: Tk_Photo;
      Button: Ttk_Button;
   begin
      Create(Tokens, Tcl.Tk.Ada.Grid.Grid_Size(CommandsFrame), " ");
      for I in 0 .. (Natural'Value(Slice(Tokens, 2)) - 1) loop
         Create
           (Tokens,
            Tcl.Tk.Ada.Grid.Grid_Slaves
              (CommandsFrame, "-row" & Positive'Image(I)),
            " ");
         for J in 1 .. Slice_Count(Tokens) loop
            Item := Get_Widget(Slice(Tokens, J));
            Destroy(Item);
         end loop;
      end loop;
      if UserCommandsList.Is_Empty then
         return;
      end if;
      Label := Create(CommandsFrame & ".name", "-text {Menu label}");
      Tcl.Tk.Ada.Grid.Grid(Label);
      Tcl.Tk.Ada.Grid.Column_Configure(CommandsFrame, Label, "-weight 1");
      Label := Create(CommandsFrame & ".command", "-text {Command}");
      Tcl.Tk.Ada.Grid.Grid(Label, "-row 0 -column 1");
      Tcl.Tk.Ada.Grid.Column_Configure(CommandsFrame, Label, "-weight 1");
      Label := Create(CommandsFrame & ".output", "-text {Output}");
      Tcl.Tk.Ada.Grid.Grid(Label, "-row 0 -column 2");
      Tcl.Tk.Ada.Grid.Column_Configure(CommandsFrame, Label, "-weight 1");
      Image.Interp := Get_Context;
      for I in UserCommandsList.Iterate loop
         Label :=
           Create
             (CommandsFrame & ".name" & Trim(Positive'Image(Row), Left),
              "-text {" & Commands_Container.Key(I) & "}");
         Tcl.Tk.Ada.Grid.Grid(Label, "-row" & Positive'Image(Row));
         Label :=
           Create
             (CommandsFrame & ".command" & Trim(Positive'Image(Row), Left),
              "-text {" & To_String(UserCommandsList(I).Command) & "}");
         Tcl.Tk.Ada.Grid.Grid
           (Label, "-row" & Positive'Image(Row) & " -column 1");
         Label :=
           (if UserCommandsList(I).NeedOutput then
              Create
                (CommandsFrame & ".output" & Trim(Positive'Image(Row), Left),
                 "-text {" & Mc(Get_Context, "{Yes}") & "}")
            else Create
                (CommandsFrame & ".output" & Trim(Positive'Image(Row), Left),
                 "-text {" & Mc(Get_Context, "{No}") & "}"));
         Tcl.Tk.Ada.Grid.Grid
           (Label, "-row" & Positive'Image(Row) & " -column 2");
         Image.Name := New_String("refreshicon");
         Button :=
           Create
             (CommandsFrame & ".editbutton" & Trim(Positive'Image(Row), Left),
              "-style Toolbutton -image " & Image &
              " -command {EditCommand {" & Commands_Container.Key(I) & "}}");
         Add
           (Button,
            Mc
              (Get_Context,
               "{Edit the selected command. If you change the menu label,\na new command will be added.}"));
         Tcl.Tk.Ada.Grid.Grid
           (Button, "-row" & Positive'Image(Row) & " -column 3");
         Image.Name := New_String("edit-deleteicon");
         Button :=
           Create
             (CommandsFrame & ".deletebutton" &
              Trim(Positive'Image(Row), Left),
              "-style Toolbutton -image " & Image &
              " -command {DeleteCommand {" & Commands_Container.Key(I) & "}}");
         Add(Button, Mc(Get_Context, "{Delete the selected command.}"));
         Tcl.Tk.Ada.Grid.Grid
           (Button, "-row" & Positive'Image(Row) & " -column 4");
         Row := Row + 1;
      end loop;
   end UpdateUserCommandsList;

   -- ****o* UserCommands/UserCommands.Execute_Command_Command
   -- FUNCTION
   -- Execute the selected user command and show its output if needed
   -- PARAMETERS
   -- ClientData - Custom data send to the command. Unused
   -- Interp     - Tcl interpreter in which command was executed. Unused
   -- Argc       - Number of arguments passed to the command. Unused
   -- Argv       - Values of arguments passed to the command.
   -- RESULT
   -- This function always return TCL_OK
   -- COMMANDS
   -- ExecuteCommand menuentry
   -- Menuentry is the menu label of the command which will be executed
   -- SOURCE
   function Execute_Command_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;
      -- ****

   function Execute_Command_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc);
      Value, CommandName: Unbounded_String;
      SpaceIndex: Natural;
      Result: Expect_Match;
      ProcessDesc: Process_Descriptor;
      Arguments: Argument_List_Access;
      Success: Boolean := False;
   begin
      Value := UserCommandsList(CArgv.Arg(Argv, 1)).Command;
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
      if SpaceIndex > 0 then
         Arguments :=
           Argument_String_To_List(Slice(Value, SpaceIndex, Length(Value)));
      end if;
      for I in Arguments'Range loop
         if Arguments(I).all = "@1" then
            Arguments(I) := new String'(To_String(CurrentDirectory));
         elsif Arguments(I).all = "@2" then
            Arguments(I) := new String'(To_String(CurrentSelected));
         end if;
      end loop;
      Non_Blocking_Spawn
        (ProcessDesc, Full_Name(To_String(CommandName)), Arguments.all);
      if UserCommandsList(CArgv.Arg(Argv, 1)).NeedOutput then
         ShowOutput;
         loop
            Expect(ProcessDesc, Result, Regexp => ".+", Timeout => 300_000);
            exit when Result /= 1;
            UpdateOutput(Expect_Out_Match(ProcessDesc) & LF);
            Success := True;
         end loop;
      end if;
      Close(ProcessDesc);
      return TCL_OK;
   exception
      when Process_Died =>
         if not Success then
            ShowMessage
              (Mc(Interp, "{Can't execute command:}") & " " &
               Slice(Value, 1, SpaceIndex));
         end if;
         return TCL_OK;
   end Execute_Command_Command;

   procedure AddCommands is
   begin
      AddCommand("ExecuteCommand", Execute_Command_Command'Access);
   end AddCommands;

end UserCommands;
