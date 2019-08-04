-- /home/thindil/Projekty/hunter/hunter/src/trash.adb
-- Copyright (c) 2019 Bartek thindil Jasicki <thindil@laeran.pl>
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
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.String_Split; use GNAT.String_Split;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Enums; use Gtk.Enums;
with Gtk.Flow_Box; use Gtk.Flow_Box;
with Gtk.Flow_Box_Child; use Gtk.Flow_Box_Child;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Main; use Gtk.Main;
with Gtk.Message_Dialog; use Gtk.Message_Dialog;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.Tree_Model_Filter; use Gtk.Tree_Model_Filter;
with Gtk.Tree_Model_Sort; use Gtk.Tree_Model_Sort;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Widget; use Gtk.Widget;
with Gtkada.Intl; use Gtkada.Intl;
with Gdk; use Gdk;
with Gdk.Cursor; use Gdk.Cursor;
with Gdk.Window; use Gdk.Window;
with Glib; use Glib;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Utils; use Utils;

package body Trash is

   -- ****iv* Trash/Accelerators
   -- FUNCTION
   -- Keyboard shortcuts for path buttons
   -- SOURCE
   Accelerators: Gtk_Accel_Group;
   -- ****

   procedure ClearTrash(Object: access Gtkada_Builder_Record'Class) is
      pragma Unreferenced(Object);
   begin
      NewAction := CLEARTRASH;
      ToggleToolButtons(NewAction);
      ShowMessage
        (Gettext("Remove all files and directories from Trash?"),
         Message_Question);
   end ClearTrash;

   -- ****if* Trash/RemovePathButtons
   -- FUNCTION
   -- Remove selected button from path buttons
   -- PARAMETERS
   -- Widget - Button to remove
   -- SOURCE
   procedure RemovePathButtons
     (Widget: not null access Gtk_Widget_Record'Class) is
   -- ****
   begin
      Set_Accel_Path(Widget, "", Accelerators);
      Destroy(Widget);
   end RemovePathButtons;

   procedure PathClicked(Self: access Gtk_Button_Record'Class) is
      Tokens: Slice_Set;
      Index: constant Gint := Get_Index(Gtk_Flow_Box_Child(Get_Parent(Self)));
   begin
      if Index = 0 then
         ShowTrash(Builder);
         return;
      end if;
      Create(Tokens, To_String(CurrentDirectory), "/");
      CurrentDirectory :=
        To_Unbounded_String(Value("HOME") & "/.local/share/Trash/files");
      for I in 2 .. (Index + 1) loop
         Append(CurrentDirectory, "/" & Slice(Tokens, Slice_Number(I)));
      end loop;
      Reload(Builder);
   end PathClicked;

   procedure ShowTrash(Object: access Gtkada_Builder_Record'Class) is
      FilesList: constant Gtk_List_Store :=
        Gtk_List_Store(Get_Object(Builder, "fileslist"));
      FileIter: Gtk_Tree_Iter;
      MainWindow: constant Gdk_Window :=
        Get_Window(Gtk_Widget(Get_Object(Object, "mainwindow")));
      Directory, SubDirectory: Dir_Type;
      Last, SubLast: Natural;
      FileName, SubFileName: String(1 .. 1024);
      FilesSort: constant Gtk_Tree_Model_Sort :=
        Gtk_Tree_Model_Sort(Get_Object(Object, "filessort"));
      FileInfo: File_Type;
      Size: File_Size;
      FileLine, FullName: Unbounded_String;
      Button: Gtk_Button;
      ButtonBox: constant Gtk_Flow_Box :=
        Gtk_Flow_Box(Get_Object(Object, "boxpath"));
   begin
      Setting := True;
      if Accelerators = null then
         Accelerators := Gtk_Accel_Group(Get_Object(Object, "accelerators"));
      end if;
      if MainWindow /= null then
         Set_Cursor(MainWindow, Gdk_Cursor_New(Watch));
         Set_Sensitive(Gtk_Widget(Get_Object(Builder, "mainwindow")), False);
         while Events_Pending loop
            if Main_Iteration_Do(False) then
               exit;
            end if;
         end loop;
      end if;
      Set_Title
        (Gtk_Tree_View_Column(Get_Object(Object, "modifiedcolumn")),
         Gettext("Deleted"));
      ToggleToolButtons(SHOWTRASH);
      FilesList.Clear;
      Set_Sort_Func
        (Gtk_Tree_Model_Sort(Get_Object(Builder, "filessort")), 0,
         EmptySortFiles'Access);
      Open(Directory, Value("HOME") & "/.local/share/Trash/files");
      loop
         Read(Directory, FileName, Last);
         exit when Last = 0;
         if FileName(1 .. Last) = "." or FileName(1 .. Last) = ".." then
            goto End_Of_Loop;
         end if;
         Append(FilesList, FileIter);
         FullName :=
           To_Unbounded_String
             (Value("HOME") & "/.local/share/Trash/files/" &
              FileName(1 .. Last));
         Set(FilesList, FileIter, 6, To_String(FullName));
         Open
           (FileInfo, In_File,
            Value("HOME") & "/.local/share/Trash/info/" & FileName(1 .. Last) &
            ".trashinfo");
         Skip_Line(FileInfo);
         for I in 1 .. 2 loop
            FileLine := To_Unbounded_String(Get_Line(FileInfo));
            if Slice(FileLine, 1, 4) = "Path" then
               Set
                 (FilesList, FileIter, 0,
                  Simple_Name(Slice(FileLine, 6, Length(FileLine))));
            else
               FileLine := Unbounded_Slice(FileLine, 14, Length(FileLine));
               Replace_Slice(FileLine, 11, 11, " ");
               Set(FilesList, FileIter, 5, To_String(FileLine));
            end if;
         end loop;
         Close(FileInfo);
         if Is_Directory(To_String(FullName)) then
            if FileName(1) = '.' then
               Set(FilesList, FileIter, 1, 1);
            else
               Set(FilesList, FileIter, 1, 2);
            end if;
            if Is_Symbolic_Link(To_String(FullName)) then
               Set(FilesList, FileIter, 2, "emblem-symbolic-link");
            else
               Set(FilesList, FileIter, 2, "folder");
            end if;
            Set(FilesList, FileIter, 4, Gint'Last);
            if Is_Read_Accessible_File(To_String(FullName)) then
               Open(SubDirectory, To_String(FullName));
               Size := 0;
               loop
                  Read(SubDirectory, SubFileName, SubLast);
                  exit when SubLast = 0;
                  Size := Size + 1;
               end loop;
               Close(SubDirectory);
               Set(FilesList, FileIter, 3, File_Size'Image(Size - 2));
            else
               Set(FilesList, FileIter, 3, "?");
            end if;
         else
            if FileName(1) = '.' then
               Set(FilesList, FileIter, 1, 3);
            else
               Set(FilesList, FileIter, 1, 4);
            end if;
            if Is_Symbolic_Link(To_String(FullName)) then
               Set(FilesList, FileIter, 2, "emblem-symbolic-link");
            else
               Set(FilesList, FileIter, 2, "text-x-generic-template");
            end if;
            if not Is_Read_Accessible_File(To_String(FullName)) then
               Set(FilesList, FileIter, 3, "?");
               Set(FilesList, FileIter, 4, 0);
               goto End_Of_Loop;
            end if;
            if Is_Symbolic_Link(To_String(FullName)) then
               Set(FilesList, FileIter, 3, "->");
               Set(FilesList, FileIter, 4, 0);
            elsif Is_Regular_File(To_String(FullName)) then
               Size := Ada.Directories.Size(To_String(FullName));
               Set(FilesList, FileIter, 3, CountFileSize(Size));
               if Size > File_Size(Gint'Last) then
                  Size := File_Size(Gint'Last);
               end if;
               Set(FilesList, FileIter, 4, Gint(Size));
            else
               Set(FilesList, FileIter, 3, "0");
               Set(FilesList, FileIter, 4, 0);
            end if;
         end if;
         <<End_Of_Loop>>
      end loop;
      Close(Directory);
      Foreach(ButtonBox, RemovePathButtons'Access);
      Gtk_New(Button, "Trash");
      Insert(ButtonBox, Button, -1);
      On_Clicked(Button, PathClicked'Access);
      Set_Tooltip_Text
        (Gtk_Widget(Button), Gettext("Reload current directory [ALT+R]"));
      Set_Accel_Path(Gtk_Widget(Button), "<mainwindow>/reload", Accelerators);
      Show_All(ButtonBox);
      Set_Sort_Func(FilesSort, 0, SortFiles'Access);
      Set_Sort_Column_Id(FilesSort, 0, Sort_Ascending);
      if MainWindow /= null then
         Set_Cursor
           (Get_Window(Gtk_Widget(Get_Object(Object, "mainwindow"))),
            Gdk_Cursor_New(Arrow));
         Set_Sensitive(Gtk_Widget(Get_Object(Object, "mainwindow")), True);
      end if;
      Setting := False;
      Refilter(Gtk_Tree_Model_Filter(Get_Object(Object, "filesfilter")));
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Object, "treefiles")),
         Gtk_Tree_Path_New_From_String("0"), null, False);
      Grab_Focus(Gtk_Widget(Get_Object(Object, "treefiles")));
   end ShowTrash;

   procedure RestoreItem(Object: access Gtkada_Builder_Record'Class) is
      RestoreInfo, FileLine, Destination, ItemType: Unbounded_String;
      StartIndex: Positive;
      FileInfo: File_Type;
   begin
      for Item of SelectedItems loop
         StartIndex := Index(Item, "files");
         RestoreInfo :=
           Unbounded_Slice(Item, 1, StartIndex - 1) & "info" &
           Unbounded_Slice(Item, StartIndex + 5, Length(Item)) &
           To_Unbounded_String(".trashinfo");
         Open(FileInfo, In_File, To_String(RestoreInfo));
         Skip_Line(FileInfo);
         for I in 1 .. 2 loop
            FileLine := To_Unbounded_String(Get_Line(FileInfo));
            if Slice(FileLine, 1, 4) = "Path" then
               Destination := Unbounded_Slice(FileLine, 6, Length(FileLine));
               if Ada.Directories.Exists(To_String(Destination)) then
                  if Is_Directory(To_String(Destination)) then
                     ItemType := To_Unbounded_String(Gettext("Directory"));
                  else
                     ItemType := To_Unbounded_String(Gettext("File"));
                  end if;
                  ShowMessage
                    (Gettext("Can't restore ") & To_String(Destination) & " " &
                     To_String(ItemType) & " " &
                     Gettext("with that name exists."));
                  Close(FileInfo);
                  ShowTrash(Object);
                  return;
               end if;
               Rename(To_String(Item), Slice(FileLine, 6, Length(FileLine)));
            end if;
         end loop;
         Close(FileInfo);
         Delete_File(To_String(RestoreInfo));
      end loop;
      ShowTrash(Object);
   end RestoreItem;

end Trash;
