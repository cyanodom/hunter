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
with Ada.Strings;
with Ada.Text_IO; use Ada.Text_IO;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Accel_Map; use Gtk.Accel_Map;
with Gtk.Dialog; use Gtk.Dialog;
with Gtk.Enums; use Gtk.Enums;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Main; use Gtk.Main;
with Gtk.Menu; use Gtk.Menu;
with Gtk.Menu_Item; use Gtk.Menu_Item;
with Gtk.Menu_Tool_Button; use Gtk.Menu_Tool_Button;
with Gtk.Paned; use Gtk.Paned;
with Gtk.Stack; use Gtk.Stack;
with Gtk.Toggle_Tool_Button; use Gtk.Toggle_Tool_Button;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.Tree_Model_Filter; use Gtk.Tree_Model_Filter;
with Gtk.Tree_Model_Sort; use Gtk.Tree_Model_Sort;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Widget; use Gtk.Widget;
with Gtk.Window; use Gtk.Window;
with Gtkada.Intl; use Gtkada.Intl;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Gdk.Event; use Gdk.Event;
with Gdk.Types; use Gdk.Types;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with ActivateItems; use ActivateItems;
with Bookmarks; use Bookmarks;
with CopyItems; use CopyItems;
with CreateItems; use CreateItems;
with DeleteItems; use DeleteItems;
with LoadData; use LoadData;
with Messages; use Messages;
with MoveItems; use MoveItems;
with Preferences; use Preferences;
with RefreshData; use RefreshData;
with SearchItems; use SearchItems;
with ShowItems; use ShowItems;
with Trash; use Trash;
with Utils; use Utils;

package body MainWindow is

   procedure Quit(Object: access Gtkada_Builder_Record'Class) is
   begin
      SavePreferences;
      if Settings.ClearTrashOnExit then
         NewAction := CLEARTRASH;
         if DeleteSelected then
            Reload(Object);
         end if;
      end if;
      Unref(Object);
      Main_Quit;
   end Quit;

   function SetSelected
     (Model: Gtk_Tree_Model; Path: Gtk_Tree_Path; Iter: Gtk_Tree_Iter)
      return Boolean is
   begin
      if Get_String(Model, Iter, 0) =
        Simple_Name(To_String(CurrentSelected)) then
         Set_Cursor
           (Gtk_Tree_View(Get_Object(Builder, "treefiles")), Path, null,
            False);
         return True;
      end if;
      return False;
   end SetSelected;

   procedure Reload(Object: access Gtkada_Builder_Record'Class) is
      OldSelected: Unbounded_String;
   begin
      if CurrentDirectory = Null_Unbounded_String then
         CurrentDirectory := To_Unbounded_String("/");
      end if;
      if CurrentSelected /= Null_Unbounded_String then
         OldSelected := CurrentSelected;
      else
         OldSelected := To_Unbounded_String(".");
      end if;
      LoadDirectory(To_String(CurrentDirectory), "fileslist");
      ToggleActionButtons;
      if N_Children
          (Get_Model(Gtk_Tree_View(Get_Object(Object, "treefiles"))),
           Null_Iter) =
        0 then
         CurrentSelected := CurrentDirectory;
      else
         if Containing_Directory(To_String(OldSelected)) /=
           To_String(CurrentDirectory) then
            OldSelected := Null_Unbounded_String;
         end if;
         if OldSelected = Null_Unbounded_String
           or else not Ada.Directories.Exists(To_String(OldSelected)) then
            Set_Cursor
              (Gtk_Tree_View(Get_Object(Builder, "treefiles")),
               Gtk_Tree_Path_New_From_String("0"), null, False);
         else
            CurrentSelected := OldSelected;
            Foreach
              (Get_Model(Gtk_Tree_View(Get_Object(Object, "treefiles"))),
               SetSelected'Access);
         end if;
         Grab_Focus(Gtk_Widget(Get_Object(Object, "treefiles")));
      end if;
      ShowItem(Object);
      UpdateTimestamp;
   end Reload;

   -- ****if* MainWindow/StartRename
   -- FUNCTION
   -- Show text entry to start renaming selected file or directory and fill it
   -- with current element name.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure StartRename(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      GEntry: constant Gtk_Widget := Gtk_Widget(Get_Object(Object, "entry"));
   begin
      NewAction := RENAME;
      if Is_Directory(To_String(CurrentSelected)) then
         Set_Icon_Tooltip_Text
           (Gtk_GEntry(GEntry), Gtk_Entry_Icon_Secondary,
            Gettext("Rename directory."));
      else
         Set_Icon_Tooltip_Text
           (Gtk_GEntry(GEntry), Gtk_Entry_Icon_Secondary,
            Gettext("Rename file."));
      end if;
      ToggleToolButtons(NewAction);
      Set_Text(Gtk_GEntry(GEntry), Simple_Name(To_String(CurrentSelected)));
      Show_All(GEntry);
      Grab_Focus(GEntry);
   end StartRename;

   -- ****if* MainWindow/ShowFiles
   -- FUNCTION
   -- Back to files listing and preview/info
   -- PARAMETERS
   -- User_Data - Which button was clicked
   -- SOURCE
   procedure ShowFiles(User_Data: access GObject_Record'Class) is
      -- ****
      pragma Unreferenced(User_Data);
   begin
      Setting := True;
      if Get_Active
          (Gtk_Toggle_Tool_Button(Get_Object(Builder, "btncopy"))) then
         CopyItemsList.Clear;
         Set_Active
           (Gtk_Toggle_Tool_Button(Get_Object(Builder, "btncopy")), False);
      end if;
      if Get_Active(Gtk_Toggle_Tool_Button(Get_Object(Builder, "btncut"))) then
         MoveItemsList.Clear;
         Set_Active
           (Gtk_Toggle_Tool_Button(Get_Object(Builder, "btncut")), False);
      end if;
      Setting := False;
      Hide(Gtk_Widget(Get_Object(Builder, "progressbar")));
      ToggleToolButtons(NewAction, True);
      HideMessage(Builder);
      Show_All(Gtk_Widget(Get_Object(Builder, "toolbar")));
      Show_All(Gtk_Widget(Get_Object(Builder, "boxpath")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolcancel")));
      Hide(Gtk_Widget(Get_Object(Builder, "boxpath2")));
      CurrentSelected := Null_Unbounded_String;
      ToggleToolButtons(NewAction, True);
      ShowItem(Builder);
   end ShowFiles;

   -- ****if* MainWindow/ShowAbout
   -- FUNCTION
   -- Show dialog with informations about the program
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure ShowAbout(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      AboutDialog: constant GObject := Get_Object(Object, "aboutdialog");
   begin
      if Run(Gtk_Dialog(AboutDialog)) = Gtk_Response_Delete_Event then
         Hide(Gtk_Widget(AboutDialog));
      end if;
   end ShowAbout;

   -- ****if* MainWindow/EntryKeyPressed
   -- FUNCTION
   -- Close text entry on press Escape key
   -- PARAMETERS
   -- Self  - Currently active entry
   -- Event - Detailed informations about key pressed event (key code,
   --         modifiers, etc)
   -- RESULT
   -- This function always return False
   -- SOURCE
   function EntryKeyPressed
     (Self: access Gtk_Widget_Record'Class; Event: Gdk.Event.Gdk_Event_Key)
      return Boolean is
   -- ****
   begin
      if Event.Keyval = GDK_Escape then
         ToggleToolButtons(NewAction, True);
         if Self = Gtk_Widget(Get_Object(Builder, "searchfile")) then
            Set_Active
              (Gtk_Toggle_Tool_Button(Get_Object(Builder, "btnsearch")),
               False);
         else
            Hide(Self);
         end if;
         if NewAction = CREATELINK then
            Hide(Gtk_Widget(Get_Object(Builder, "boxpath2")));
            Set_Visible_Child_Name
              (Gtk_Stack(Get_Object(Builder, "infostack")), "preview");
            NewAction := CREATEFILE;
         end if;
         PreviewItem(Builder);
      end if;
      return False;
   end EntryKeyPressed;

   -- ****if* MainWindow/UpdateImage
   -- FUNCTION
   -- If scaling images in preview is enabled, scale it on resize preview of it
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- RESULT
   -- This function always return False
   -- SOURCE
   function UpdateImage
     (Object: access Gtkada_Builder_Record'Class) return Boolean is
   -- ****
   begin
      if not Settings.ScaleImages then
         return False;
      end if;
      PreviewItem(Object);
      return False;
   end UpdateImage;

   -- ****if* MainWindow/WindowKeyPressed
   -- FUNCTION
   -- Close the program with keyboard shortcut
   -- PARAMETERS
   -- Self  - Main window of the program (not used)
   -- Event - Detailed informations about key pressed event (key code,
   --         modifiers, etc)
   -- RESULT
   -- This function always return False
   -- SOURCE
   function WindowKeyPressed
     (Self: access Gtk_Widget_Record'Class; Event: Gdk.Event.Gdk_Event_Key)
      return Boolean is
      pragma Unreferenced(Self);
      -- ****
      KeyMods: constant Gdk_Modifier_Type :=
        Event.State and Get_Default_Mod_Mask;
      Key: Gtk_Accel_Key;
      Found: Boolean;
   begin
      Lookup_Entry("<mainwindow>/quit", Key, Found);
      if not Found then
         return False;
      end if;
      if Key.Accel_Key = Event.Keyval and Key.Accel_Mods = KeyMods then
         Quit(Builder);
      end if;
      return False;
   end WindowKeyPressed;

   -- ****if* MainWindow/GetWindowSize
   -- FUNCTION
   -- Get the main window size at quitting of the program
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- RESULT
   -- This function always return False
   -- SOURCE
   function GetWindowSize
     (Object: access Gtkada_Builder_Record'Class) return Boolean is
   -- ****
   begin
      Settings.WindowWidth :=
        Positive
          (Get_Allocated_Width(Gtk_Widget(Get_Object(Object, "mainwindow"))));
      Settings.WindowHeight :=
        Positive
          (Get_Allocated_Height(Gtk_Widget(Get_Object(Object, "mainwindow"))));
      return False;
   end GetWindowSize;

   -- ****if* MainWindow/ShowFilesMenu
   -- FUNCTION
   -- Show menu with available actions on right click on directory listing
   -- PARAMETERS
   -- Self  - Tree view to which menu is attached. Unused
   -- Event - Detailed info about mouse press button event
   -- RESULT
   -- Return True if pressed button was right button, otherwise False
   -- SOURCE
   function ShowFilesMenu
     (Self: access Gtk_Widget_Record'Class; Event: Gdk_Event_Button)
      return Boolean is
      pragma Unreferenced(Self);
      -- ****
      FilesMenu: constant Gtk_Menu :=
        Gtk_Menu(Get_Object(Builder, "filesmenu"));
      FilesTree: constant Gtk_Tree_View :=
        Gtk_Tree_View(Get_Object(Builder, "treefiles"));
   begin
      if Event.Button /= 3 then
         return False;
      end if;
      if Count_Selected_Rows(Get_Selection(FilesTree)) =
        N_Children(Get_Model(FilesTree)) then
         Set_Label
           (Gtk_Menu_Item(Get_Object(Builder, "menuselectall")),
            Gettext("Unselect all"));
      else
         Set_Label
           (Gtk_Menu_Item(Get_Object(Builder, "menuselectall")),
            Gettext("Select all"));
      end if;
      Show_All(Gtk_Widget(FilesMenu));
      Set_Visible
        (Gtk_Widget(Get_Object(Builder, "menuopen")),
         Get_Visible(Gtk_Widget(Get_Object(Builder, "btnopen"))));
      Set_Visible
        (Gtk_Widget(Get_Object(Builder, "menurun")),
         Get_Visible(Gtk_Widget(Get_Object(Builder, "btnrun"))));
      Set_Visible
        (Gtk_Widget(Get_Object(Builder, "menurunwith")),
         Get_Visible(Gtk_Widget(Get_Object(Builder, "btnopenwith"))));
      Set_Visible
        (Gtk_Widget(Get_Object(Builder, "menurename")),
         Get_Visible(Gtk_Widget(Get_Object(Builder, "btnopenwith"))));
      if not Is_Visible(Gtk_Widget(Get_Object(Builder, "itemtoolbar"))) then
         Hide(Gtk_Widget(Get_Object(Builder, "menuopen")));
         Hide(Gtk_Widget(Get_Object(Builder, "menurun")));
         Hide(Gtk_Widget(Get_Object(Builder, "menurunwith")));
         Hide(Gtk_Widget(Get_Object(Builder, "menurename")));
      end if;
      Popup
        (Menu => FilesMenu, Button => Event.Button,
         Activate_Time => Event.Time);
      return True;
   end ShowFilesMenu;

   -- ****if* MainWindow/ShowFile
   -- FUNCTION
   -- Show README.md or CHANGELOG.md file
   -- PARAMETERS
   -- User_Data - Which menu item was selected
   -- SOURCE
   procedure ShowFile(User_Data: access GObject_Record'Class) is
      -- ****
      FileName: Unbounded_String := To_Unbounded_String("README.md");
      FilesList: constant Gtk_Tree_Model_Sort :=
        Gtk_Tree_Model_Sort(Get_Object(Builder, "filessort"));
      FilesIter: Gtk_Tree_Iter;
   begin
      CurrentDirectory :=
        To_Unbounded_String(Containing_Directory(Current_Directory));
      if Ada.Environment_Variables.Exists("APPDIR") then
         CurrentDirectory :=
           To_Unbounded_String(Value("APPDIR") & "/usr/share/docs");
      end if;
      if User_Data = Get_Object(Builder, "aboutchangelog") then
         FileName := To_Unbounded_String("CHANGELOG.md");
      end if;
      Reload(Builder);
      FilesIter := Get_Iter_First(FilesList);
      loop
         if Get_String(FilesList, FilesIter, 0) = To_String(FileName) then
            Set_Cursor
              (Gtk_Tree_View(Get_Object(Builder, "treefiles")),
               Get_Path(FilesList, FilesIter), null, False);
            exit;
         end if;
         Next(FilesList, FilesIter);
         exit when not Iter_Is_Valid(FilesList, FilesIter);
      end loop;
   end ShowFile;

   procedure SelectAll(Object: access Gtkada_Builder_Record'Class) is
      FilesTree: constant Gtk_Tree_View :=
        Gtk_Tree_View(Get_Object(Object, "treefiles"));
      Selection: constant Gtk_Tree_Selection := Get_Selection(FilesTree);
   begin
      if Count_Selected_Rows(Selection) = N_Children(Get_Model(FilesTree)) then
         Unselect_All(Selection);
         Set_Cursor
           (FilesTree, Gtk_Tree_Path_New_From_String("0"), null, False);
         Grab_Focus(Gtk_Widget(FilesTree));
      else
         Select_All(Selection);
      end if;
   end SelectAll;

   procedure CreateMainWindow(NewBuilder: Gtkada_Builder; Directory: String) is
   begin
      Setting := True;
      Builder := NewBuilder;
      Register_Handler(Builder, "Main_Quit", Quit'Access);
      Register_Handler(Builder, "Show_Item", ShowItem'Access);
      Register_Handler(Builder, "Toggle_Search", ToggleSearch'Access);
      Register_Handler(Builder, "Delete_Item", DeleteItem'Access);
      Register_Handler(Builder, "Start_Rename", StartRename'Access);
      Register_Handler(Builder, "Move_Items", MoveData'Access);
      Register_Handler(Builder, "Copy_Items", CopyData'Access);
      Register_Handler(Builder, "Preview_Item", PreviewItem'Access);
      Register_Handler(Builder, "Show_Item_Info", ShowItemInfo'Access);
      Register_Handler(Builder, "Show_Files", ShowFiles'Access);
      Register_Handler(Builder, "Set_Associated", SetAssociated'Access);
      Register_Handler(Builder, "Search_Items", SearchItem'Access);
      Register_Handler(Builder, "Set_Permission", SetPermission'Access);
      Register_Handler(Builder, "Show_About", ShowAbout'Access);
      Register_Handler
        (Builder, "Toggle_Preferences", TogglePreferences'Access);
      Register_Handler(Builder, "Save_Preferences", SaveSettings'Access);
      Register_Handler(Builder, "Update_Image", UpdateImage'Access);
      Register_Handler
        (Builder, "Save_Preferences_Proc", SaveSettingsProc'Access);
      Register_Handler(Builder, "Get_Window_Size", GetWindowSize'Access);
      Register_Handler(Builder, "Clear_Trash", ClearTrash'Access);
      Register_Handler(Builder, "Show_Trash", ShowTrash'Access);
      Register_Handler(Builder, "Restore_Item", RestoreItem'Access);
      Register_Handler(Builder, "Show_File", ShowFile'Access);
      Register_Handler(Builder, "Select_All", SelectAll'Access);
      CreateActivateUI;
      CreateBookmarksUI;
      CreateCreateUI;
      CreateMessagesUI;
      Do_Connect(Builder);
      Set_Visible_Func
        (Gtk_Tree_Model_Filter(Get_Object(Builder, "filesfilter")),
         VisibleItems'Access);
      Set_Visible_Func
        (Gtk_Tree_Model_Filter(Get_Object(Builder, "filesfilter1")),
         VisibleItems'Access);
      Set_Visible_Func
        (Gtk_Tree_Model_Filter(Get_Object(Builder, "filesfilter2")),
         VisibleItems'Access);
      Set_Visible_Func
        (Gtk_Tree_Model_Filter(Get_Object(Builder, "applicationsfilter")),
         VisibleItems'Access);
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "entry")), EntryKeyPressed'Access);
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "searchfile")),
         EntryKeyPressed'Access);
      On_Key_Press_Event
        (Gtk_Widget(Get_Object(Builder, "mainwindow")),
         WindowKeyPressed'Access);
      On_Button_Press_Event
        (Gtk_Widget(Get_Object(Builder, "treefiles")), ShowFilesMenu'Access);
      Add_Entry("<mainwindow>/reload", GDK_LC_r, Mod1_Mask);
      Add_Entry("<mainwindow>/goup", GDK_LC_u, Mod1_Mask);
      Add_Entry("<mainwindow>/path1", GDK_1, Mod1_Mask);
      Add_Entry("<mainwindow>/path2", GDK_2, Mod1_Mask);
      Add_Entry("<mainwindow>/path3", GDK_3, Mod1_Mask);
      Add_Entry("<mainwindow>/path4", GDK_4, Mod1_Mask);
      Add_Entry("<mainwindow>/path5", GDK_5, Mod1_Mask);
      Add_Entry("<mainwindow>/path6", GDK_6, Mod1_Mask);
      Add_Entry("<mainwindow>/path7", GDK_7, Mod1_Mask);
      Add_Entry("<mainwindow>/path8", GDK_8, Mod1_Mask);
      Add_Entry("<mainwindow>/path9", GDK_9, Mod1_Mask);
      Add_Entry("<mainwindow>/reload2", GDK_LC_r, Mod1_Mask + Shift_Mask);
      Add_Entry("<mainwindow>/goup2", GDK_LC_u, Mod1_Mask + Shift_Mask);
      Add_Entry("<mainwindow>/path12", GDK_exclam, Mod1_Mask);
      Add_Entry("<mainwindow>/path22", GDK_at, Mod1_Mask);
      Add_Entry("<mainwindow>/path32", GDK_numbersign, Mod1_Mask);
      Add_Entry("<mainwindow>/path42", GDK_dollar, Mod1_Mask);
      Add_Entry("<mainwindow>/path52", GDK_percent, Mod1_Mask);
      Add_Entry("<mainwindow>/path62", GDK_asciicircum, Mod1_Mask);
      Add_Entry("<mainwindow>/path72", GDK_ampersand, Mod1_Mask);
      Add_Entry("<mainwindow>/path82", GDK_parenleft, Mod1_Mask);
      Add_Entry("<mainwindow>/path92", GDK_parenright, Mod1_Mask);
      Add_Entry("<mainwindow>/quit", GDK_LC_q, Control_Mask);
      if Ada.Directories.Exists(Directory) then
         CurrentDirectory := To_Unbounded_String(Directory);
      else
         CurrentDirectory := To_Unbounded_String(Value("HOME"));
         if not Ada.Directories.Exists(To_String(CurrentDirectory)) then
            CurrentDirectory := To_Unbounded_String("/");
         end if;
      end if;
      declare
         ApplicationsPaths: constant array
           (Positive range <>) of Unbounded_String :=
           (To_Unbounded_String("/usr/share/applications"),
            To_Unbounded_String("/usr/share/applnk"),
            To_Unbounded_String("/usr/local/share/applications"),
            To_Unbounded_String("/usr/local/share/applnk"),
            To_Unbounded_String(Value("HOME") & "/.local/share/applications"),
            To_Unbounded_String(Value("HOME") & "/.local/share/applnk"));
         SubDirectory: Dir_Type;
         SubLast: Natural;
         SubFileName: String(1 .. 1024);
         File: File_Type;
         FileLine: Unbounded_String;
         FilesList: constant Gtk_List_Store :=
           Gtk_List_Store(Get_Object(Builder, "applicationslist"));
         FileIter: Gtk_Tree_Iter;
         NamesList: UnboundedString_Container.Vector;
      begin
         for Path of ApplicationsPaths loop
            if not Ada.Directories.Exists(To_String(Path)) then
               goto End_Of_Loop;
            end if;
            Open(SubDirectory, To_String(Path));
            loop
               Read(SubDirectory, SubFileName, SubLast);
               exit when SubLast = 0;
               if Extension(SubFileName(1 .. SubLast)) = "desktop" then
                  Open
                    (File, In_File,
                     To_String(Path) & "/" &
                     Simple_Name(SubFileName(1 .. SubLast)));
                  while not End_Of_File(File) loop
                     FileLine := To_Unbounded_String(Get_Line(File));
                     if Length(FileLine) > 5
                       and then Slice(FileLine, 1, 5) = "Name="
                       and then not NamesList.Contains
                         (Unbounded_Slice(FileLine, 6, Length(FileLine))) then
                        Append(FilesList, FileIter);
                        Set
                          (FilesList, FileIter, 0,
                           Slice(FileLine, 6, Length(FileLine)));
                        Set(FilesList, FileIter, 1, SubFileName(1 .. SubLast));
                        NamesList.Append
                          (Unbounded_Slice(FileLine, 6, Length(FileLine)));
                        exit;
                     end if;
                  end loop;
                  Close(File);
               end if;
            end loop;
            Close(SubDirectory);
            <<End_Of_Loop>>
         end loop;
      end;
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btnnew")),
         Gtk_Widget(Get_Object(Builder, "newmenu")));
      LoadSettings;
      CreateBookmarkMenu(Builder);
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btnbookmarks")),
         Gtk_Widget(Get_Object(Builder, "bookmarksmenu")));
      Set_Sort_Column_Id
        (Gtk_Tree_Model_Sort(Get_Object(Builder, "applicationssort")), 0,
         Sort_Ascending);
      Set_Default_Size
        (Gtk_Window(Get_Object(Builder, "mainwindow")),
         Gint(Settings.WindowWidth), Gint(Settings.WindowHeight));
      Attach_To_Widget
        (Gtk_Menu(Get_Object(Builder, "filesmenu")),
         Gtk_Widget(Get_Object(Builder, "treefiles")), null);
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btndelete")),
         Gtk_Widget(Get_Object(Builder, "deletemenu")));
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btnabout")),
         Gtk_Widget(Get_Object(Builder, "aboutmenu")));
      Show_All(Gtk_Widget(Get_Object(Builder, "mainwindow")));
      HideMessage(Builder);
      Hide(Gtk_Widget(Get_Object(Builder, "searchfile")));
      Hide(Gtk_Widget(Get_Object(Builder, "entry")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolcancel")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolrestore")));
      Hide(Gtk_Widget(Get_Object(Builder, "progressbar")));
      Set_Visible
        (Get_Column(Gtk_Tree_View(Get_Object(Builder, "treefiles")), 2),
         Settings.ShowLastModified);
      Reload(Builder);
      if Settings.ShowPreview then
         Set_Position
           (Gtk_Paned(Get_Object(Builder, "filespaned")),
            Gint
              (Float
                 (Get_Allocated_Width
                    (Gtk_Widget(Get_Object(Builder, "mainwindow")))) *
               0.3));
      else
         Hide(Gtk_Widget(Get_Object(Builder, "boxsecond")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnpreview")));
         Hide(Gtk_Widget(Get_Object(Builder, "btnfileinfo")));
         Set_Position
           (Gtk_Paned(Get_Object(Builder, "filespaned")),
            Get_Allocated_Width
              (Gtk_Widget(Get_Object(Builder, "mainwindow"))));
      end if;
      Grab_Focus(Gtk_Widget(Get_Object(Builder, "treefiles")));
      StartTimer;
      Setting := False;
   end CreateMainWindow;

end MainWindow;
