-----------------------------------------------------------------------
--               GtkAda - Ada95 binding for Gtk+/Gnome               --
--                                                                   --
--                   Copyright (C) 2001 ACT-Europe                   --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Gdk.Color;       use Gdk.Color;
with Gdk.Event;       use Gdk.Event;
with Glib;            use Glib;
with Gtk.Arguments;   use Gtk.Arguments;
with Gtk.Box;         use Gtk.Box;
with Gtk.Button;      use Gtk.Button;
with Gtk.Clist;       use Gtk.Clist;
with Gtk.Dialog;      use Gtk.Dialog;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Handlers;    use Gtk.Handlers;
with Gtk.Label;       use Gtk.Label;
with Gtk.Menu;        use Gtk.Menu;
with Gtk.Menu_Item;   use Gtk.Menu_Item;
with Gtk.Notebook;    use Gtk.Notebook;
with Gtk.Scrolled_Window; use Gtk.Scrolled_Window;
with Gtk.Stock;       use Gtk.Stock;
with Gtk.Style;       use Gtk.Style;
with Gtk.Widget;      use Gtk.Widget;
with Gtkada.Handlers; use Gtkada.Handlers;
with Gtkada.Types;    use Gtkada.Types;
with Pango.Font;      use Pango.Font;

with Ada.Calendar;
with GNAT.Calendar.Time_IO;     use GNAT.Calendar.Time_IO;
with GNAT.Calendar;             use GNAT.Calendar;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with Interfaces.C.Strings;      use Interfaces.C.Strings;
with Interfaces.C;              use Interfaces.C;

with Prj_API;              use Prj_API;
with Prj_Normalize;        use Prj_Normalize;
with Project_Trees;        use Project_Trees;
with Glide_Kernel;         use Glide_Kernel;
with Glide_Kernel.Project; use Glide_Kernel.Project;
with GUI_Utils;            use GUI_Utils;

with Prj;           use Prj;
with Prj.Tree;      use Prj.Tree;
with Stringt;       use Stringt;
with Types;         use Types;
with Namet;         use Namet;

with Switches_Editors; use Switches_Editors;

package body Project_Viewers is

   Timestamp_Picture : constant Picture_String := "%Y/%m/%d %H:%M:%S";
   --  <preference> Format used to display timestamps

   Default_Switches_Color : constant String := "#777777";
   --  <preference> Color to use when displaying switches that are not file
   --  specific, but set at the project or package level.

   Switches_Editor_Title_Font : constant String := "helvetica bold oblique 14";
   --  <preference> Font to use for the switches editor dialog

   type View_Display is access procedure
     (Viewer    : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style);
   --  Procedure used to return the contents of one of the columns.
   --  The returned string (Line) will be freed by the caller.
   --  Style is the style to apply to the matching cell in the clist.

   type View_Callback is access procedure
     (Viewer    : access Project_Viewer_Record'Class;
      Column    : Gint;
      File_Name : String_Id;
      Directory : String_Id);
   --  Callback called every time the user selects a column in one of the
   --  view. The view is not passed as a parameter, but can be obtained
   --  directly from the Viewer, since this is the current view displayed in
   --  the viewer

   type View_Display_Array is array (Interfaces.C.size_t range <>)
     of View_Display;

   type View_Callback_Array is array (Interfaces.C.size_t range <>)
     of View_Callback;

   type View_Description (Num_Columns : Interfaces.C.size_t) is record
      Titles : Interfaces.C.Strings.chars_ptr_array (1 .. Num_Columns);
      --  The titles for all the columns

      Tab_Title : String_Access;
      --  The label for the notebook page that contains the view

      Display : View_Display_Array (1 .. Num_Columns);
      --  The functions to display each of the columns. null can be provided
      --  if the columns doesn't contain any information.

      Callbacks : View_Callback_Array (1 .. Num_Columns);
      --  The callbacks to call when a column is clicked. If null, no callback
      --  is called.
   end record;
   type View_Description_Access is access constant View_Description;


   type Switch_Editor_User_Data is record
      Viewer    : Project_Viewer;
      Switches  : Switches_Edit;
      File_Name : String_Id;
      Directory : String_Id;
   end record;

   package Switch_Callback is new Gtk.Handlers.User_Callback
     (Gtk_Widget_Record, Switch_Editor_User_Data);

   procedure Name_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style);
   --  Return the name of the file

   procedure Size_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style);
   --  Return the size of the file

   procedure Timestamp_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style);
   --  Return the timestamp for the file

   procedure Compiler_Switches_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style);
   --  Return the switches used for the compiler

   procedure Edit_Switches_Callback
     (Viewer    : access Project_Viewer_Record'Class;
      Column    : Gint;
      File_Name : String_Id;
      Directory : String_Id);
   --  Called every time the user wans to edit some specific switches

   View_System : aliased constant View_Description :=
     (Num_Columns => 3,
      Titles      => "File Name" + "Size" + "Last_Modified",
      Tab_Title   => new String' ("System"),
      Display     => (Name_Display'Access,
                      Size_Display'Access,
                      Timestamp_Display'Access),
      Callbacks   => (null, null, null));
   View_Version_Control : aliased constant View_Description :=
     (Num_Columns => 3,
      Titles      => "File Name" + "Revision" + "Head Revision",
      Tab_Title   => new String' ("VCS"),
      Display     => (Name_Display'Access, null, null),
      Callbacks   => (null, null, null));
   View_Switches : aliased constant View_Description :=
     (Num_Columns => 2,
      Titles      => "File Name" + "Compiler",
      Tab_Title   => new String' ("Switches"),
      Display     => (Name_Display'Access,
                      Compiler_Switches_Display'Access),
      Callbacks   => (null,
                      Edit_Switches_Callback'Access));

   Views : array (View_Type) of View_Description_Access :=
     (View_System'Access, View_Version_Control'Access, View_Switches'Access);

   type User_Data is record
      File_Name : String_Id;
      Directory : String_Id;
   end record;
   package Project_User_Data is new Row_Data (User_Data);

   function Current_Page (Viewer : access Project_Viewer_Record'Class)
      return View_Type;
   pragma Inline (Current_Page);
   --  Return the view associated with the current page of Viewer.

   procedure Append_Line
     (Viewer : access Project_Viewer_Record'Class;
      Project_View : Project_Id;
      File_Name : String_Id;
      Directory_Filter : Filter := No_Filter);
   --  Append a new line in the current page of Viewer, for File_Name.
   --  The exact contents inserted depends on the current view.
   --  The file is automatically searched in all the source directories of
   --  Project_View.

   procedure Close_Switch_Editor
     (Button : access Gtk_Widget_Record'Class;
      Data   : Switch_Editor_User_Data);
   procedure Cancel_Switch_Editor
     (Dialog : access Gtk_Widget_Record'Class);
   --  Called when the user has closed a switch editor for a specific file.
   --  The first version if the callback for the Close button, the second one
   --  is for the "cancel".

   function Append_Line_With_Full_Name
     (Viewer : access Project_Viewer_Record'Class;
      Current_View : View_Type;
      Project_View : Project_Id;
      File_Name : String;
      Directory_Name : String) return Gint;
   --  Same as above, except we have already found the proper location for
   --  the file.
   --  Return the number of the newly inserted row

   function Find_In_Source_Dirs
     (Project_View : Project_Id; File : String) return String_Id;
   --  Return the location of File in the source dirs of Project_View.
   --  null is returned if the file wasn't found.

   procedure Switch_Page
     (Viewer : access Gtk_Widget_Record'Class; Args : Gtk_Args);
   --  Callback when a new page is selected in Viewer.
   --  If the page is not up-to-date, we refresh its contents

   procedure Select_Row
     (Viewer : access Gtk_Widget_Record'Class; Args : Gtk_Args);
   --  Callback when a row/column has been selected in the clist

   function To_String (Value : Variable_Value) return String;
   --  Convert a variable value to a string suitable for insertion in the list.

   function To_Argument_List (Value : Variable_Value) return Argument_List;
   --  Convert a variable value to a list of arguments.

   procedure Explorer_Selection_Changed
     (Viewer : access Gtk_Widget_Record'Class);
   --  Called every time the selection has changed in the tree

   function Viewer_Contextual_Menu
     (Viewer : access Gtk_Widget_Record'Class; Event : Gdk_Event)
      return Gtk_Menu;
   --  Return the contextual menu to use for the project viewer

   -------------------------
   -- Find_In_Source_Dirs --
   -------------------------

   function Find_In_Source_Dirs
     (Project_View : Project_Id; File : String) return String_Id
   is
      Dirs : String_List_Id := Projects.Table (Project_View).Source_Dirs;
      File_A : String_Access;
   begin
      --  We do not use Ada_Include_Path to locate the source file,
      --  since this would include directories from imported project
      --  files, and thus slow down the search. Instead, we search
      --  in all the directories directly belong to the project.

      while Dirs /= Nil_String loop
         String_To_Name_Buffer (String_Elements.Table (Dirs).Value);
         File_A := Locate_Regular_File (File, Name_Buffer (1 .. Name_Len));
         if File_A /= null then
            Free (File_A);
            return String_Elements.Table (Dirs).Value;
         end if;
         Dirs := String_Elements.Table (Dirs).Next;
      end loop;

      return No_String;
   end Find_In_Source_Dirs;

   ---------------
   -- To_String --
   ---------------

   function To_String (Value : Variable_Value) return String is
      Buffer : String (1 .. 1024);
      Current    : Prj.String_List_Id;
      The_String : String_Element;
      Index : Natural := Buffer'First;
   begin
      case Value.Kind is
         when Prj.Undefined =>
            return "";

         when Prj.Single =>
            String_To_Name_Buffer (Value.Value);
            return Name_Buffer (1 .. Name_Len);

         when Prj.List =>
            Current := Value.Values;
            while Current /= Prj.Nil_String loop
               The_String := String_Elements.Table (Current);
               String_To_Name_Buffer (The_String.Value);

               if Index /= Buffer'First then
                  Buffer (Index) := ' ';
                  Index := Index + 1;
               end if;

               Buffer (Index .. Index + Name_Len - 1) :=
                 Name_Buffer (1 .. Name_Len);
               Index := Index + Name_Len;

               Current := The_String.Next;
            end loop;
            return Buffer (Buffer'First .. Index - 1);
      end case;
   end To_String;

   ----------------------
   -- To_Argument_List --
   ----------------------

   function To_Argument_List (Value : Variable_Value) return Argument_List is
      S : Argument_List (1 .. Length (Value)) := (others => null);
      V : String_List_Id;
   begin
      case Value.Kind is
         when Undefined =>
            null;

         when Single =>
            String_To_Name_Buffer (Value.Value);
            S (1) := new String' (Name_Buffer (1 .. Name_Len));

         when List =>
            V := Value.Values;
            for J in S'Range loop
               String_To_Name_Buffer (String_Elements.Table (V).Value);
               S (J) := new String' (Name_Buffer (1 .. Name_Len));
               V := String_Elements.Table (V).Next;
            end loop;
      end case;
      return S;
   end To_Argument_List;

   -------------------------------
   -- Compiler_Switches_Display --
   -------------------------------

   procedure Compiler_Switches_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style)
   is
      File     : Name_Id;
      Value    : Variable_Value;
      Is_Default : Boolean;
   begin
      Name_Len := File_Name'Length;
      Name_Buffer (1 .. Name_Len) := File_Name;
      File := Name_Find;

      Get_Switches
        (Viewer.Project_Filter, "compiler", File, Value, Is_Default);
      Line := New_String (To_String (Value));
      if Is_Default then
         Style := Viewer.Default_Switches_Style;
      end if;
   end Compiler_Switches_Display;

   ------------------
   -- Name_Display --
   ------------------

   procedure Name_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style)
   is
      pragma Warnings (Off, Viewer);
      pragma Warnings (Off, Directory);
      pragma Warnings (Off, Fd);
   begin
      Style := null;
      Line  := New_String (File_Name);
   end Name_Display;

   ------------------
   -- Size_Display --
   ------------------

   procedure Size_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style)
   is
      pragma Warnings (Off, Viewer);
      pragma Warnings (Off, Directory);
      pragma Warnings (Off, File_Name);
   begin
      Style := null;
      Line := New_String (Long_Integer'Image (File_Length (Fd)));
   end Size_Display;

   -----------------------
   -- Timestamp_Display --
   -----------------------

   procedure Timestamp_Display
     (Viewer : access Project_Viewer_Record'Class;
      File_Name : String;
      Directory : String;
      Fd        : File_Descriptor;
      Line      : out Interfaces.C.Strings.chars_ptr;
      Style     : out Gtk_Style)
   is
      pragma Warnings (Off, Viewer);
      pragma Warnings (Off, Directory);
      pragma Warnings (Off, File_Name);
      type Char_Pointer is access Character;
      type tm is record
         tm_sec    : Integer;
         tm_min    : Integer;
         tm_hour   : Integer;
         tm_mday   : Integer;
         tm_mon    : Integer;
         tm_year   : Integer;
         tm_wday   : Integer;
         tm_yday   : Integer;
         tm_isdst  : Integer;
         tm_gmtoff : Long_Integer;
         tm_zone   : Char_Pointer;
      end record;

      procedure localtime_r
        (C : in out OS_Time; res : out tm);
      pragma Import (C, localtime_r, "__gnat_localtime_r");
      T : tm;
      A_Time : Ada.Calendar.Time;
      O_Time : OS_Time;
   begin
      O_Time := File_Time_Stamp (Fd);
      localtime_r (O_Time, T);

      --  Make sure the values returned by localtime are in the
      --  appropriate range
      T.tm_mon := T.tm_mon + 1;
      A_Time := Time_Of (1900 + T.tm_year, T.tm_mon, T.tm_mday,
                         T.tm_hour, T.tm_min, T.tm_sec);
      Line := New_String (Image (A_Time, Timestamp_Picture));
      Style := null;
   end Timestamp_Display;

   -------------------------
   -- Close_Switch_Editor --
   -------------------------

   procedure Close_Switch_Editor
     (Button : access Gtk_Widget_Record'Class;
      Data   : Switch_Editor_User_Data)
   is
      S : Switches_Edit := Data.Switches;
      Project : Project_Node_Id := Get_Project_From_View
        (Data.Viewer.Current_Project);
      Case_Item, Decl, List, Expr, Pkg : Project_Node_Id;
      Switches_Name : Name_Id;
      Found : Boolean := False;

   begin
      pragma Assert (Project /= Empty_Node);

      --  Normalize the subproject we are currently working on, since we only
      --  know how to modify normalized subprojects.
      --  ??? Should check whether the project is already normalized.

      Normalize_Project (Project);

      --  Create the string list for all the switches

      List := Default_Project_Node (N_Literal_String_List, Prj.List);
      declare
         Args : Argument_List := Get_Switches (S, Compiler);
      begin
         for A in Args'Range loop
            Start_String;
            Store_String_Chars (Args (A).all);
            Expr := String_As_Expression (End_String);
            Set_Next_Expression_In_List
              (Expr, First_Expression_In_List (List));
            Set_First_Expression_In_List (List, Expr);
         end loop;

         Free (Args);
      end;

      --  Do we already have some declarations for this variable
      --  If yes, we simply update them. Note that we need to update all of the
      --  declarations, in case the user has put multiple of these.

      Name_Len := 8;
      Name_Buffer (1 .. Name_Len) := "switches";
      Switches_Name := Name_Find;

      Pkg := Get_Or_Create_Package (Project, "compiler");
      Case_Item := Current_Scenario_Case_Item (Project, Pkg);

      Decl := First_Declarative_Item_Of (Case_Item);
      while Decl /= Empty_Node loop
         Expr := Current_Item_Node (Decl);

         if Kind_Of (Expr) = N_Attribute_Declaration
           and then Name_Of (Expr) = Switches_Name
           and then Associative_Array_Index_Of (Expr) /= No_String
           and then String_Equal
           (Associative_Array_Index_Of (Expr), Data.File_Name)
         then
            Set_Current_Term (First_Term (Expression_Of (Expr)), List);
            Found := True;
         end if;

            Decl := Next_Declarative_Item (Decl);
      end loop;

      --  Create the new instruction to be added to the project

      if not Found then
         Decl := Get_Or_Create_Attribute
           (Case_Item, "switches", Data.File_Name);
         Set_Expression_Of (Decl, Enclose_In_Expression (List));
      end if;

      Recompute_View (Data.Viewer.Kernel);
      Destroy (Get_Toplevel (Button));
   end Close_Switch_Editor;

   --------------------------
   -- Cancel_Switch_Editor --
   --------------------------

   procedure Cancel_Switch_Editor
     (Dialog : access Gtk_Widget_Record'Class) is
   begin
      Destroy (Dialog);
   end Cancel_Switch_Editor;

   ----------------------------
   -- Edit_Switches_Callback --
   ----------------------------

   procedure Edit_Switches_Callback
     (Viewer    : access Project_Viewer_Record'Class;
      Column    : Gint;
      File_Name : String_Id;
      Directory : String_Id)
   is
      File : Name_Id;
      Tool : Tool_Names;
      Switches : Switches_Edit;
      Dialog : Gtk_Dialog;
      Button : Gtk_Button;
      Label  : Gtk_Label;
      Value : Variable_Value;
      Is_Default : Boolean;
      Desc : Pango_Font_Description;
      Style : Gtk_Style;

   begin
      String_To_Name_Buffer (File_Name);
      File := Name_Find;

      case Column is
         when 1      => Tool := Gnatmake;
         when 2      => Tool := Compiler;
         when 3      => Tool := Binder;
         when 4      => Tool := Linker;
         when others => return;
      end case;

      Gtk_New (Dialog);

      String_To_Name_Buffer (File_Name);
      Gtk_New (Label, "Editing switches for " & Name_Buffer (1 .. Name_Len));
      Pack_Start (Get_Vbox (Dialog), Label, Padding => 10);

      Style := Copy (Get_Style (Label));
      Desc := From_String (Switches_Editor_Title_Font);
      Set_Font_Description (Style, Desc);
      Set_Style (Label, Style);


      Gtk_New (Switches);
      Pack_Start (Get_Vbox (Dialog),
                  Get_Window (Switches), Fill => True, Expand => True);

      Destroy_Pages (Switches, Gnatmake_Page or Binder_Page or Linker_Page);

      --  Set the switches for all the pages
      Get_Switches
        (Viewer.Project_Filter, "compiler", File, Value, Is_Default);
      declare
         List : Argument_List := To_Argument_List (Value);
      begin
         Set_Switches (Switches, Compiler, List);
         Free (List);
      end;

      Gtk_New_From_Stock (Button, Stock_Ok);
      Pack_Start
        (Get_Action_Area (Dialog), Button, Fill => False, Expand => False);
      Switch_Callback.Connect
        (Button, "clicked",
         Switch_Callback.To_Marshaller (Close_Switch_Editor'Access),
         (Viewer    => Project_Viewer (Viewer),
          Switches  => Switches,
          File_Name => File_Name,
          Directory => Directory));

      Gtk_New_From_Stock (Button, Stock_Cancel);
      Pack_Start
        (Get_Action_Area (Dialog), Button, Fill => False, Expand => False);
      Widget_Callback.Object_Connect
        (Button, "clicked",
         Widget_Callback.To_Marshaller (Cancel_Switch_Editor'Access), Dialog);

      Show_All (Dialog);
   end Edit_Switches_Callback;

   --------------------------------
   -- Append_Line_With_Full_Name --
   --------------------------------

   function Append_Line_With_Full_Name
     (Viewer : access Project_Viewer_Record'Class;
      Current_View : View_Type;
      Project_View : Project_Id;
      File_Name : String;
      Directory_Name : String) return Gint
   is
      Line : Gtkada.Types.Chars_Ptr_Array
        (1 .. Views (Current_View).Num_Columns);
      Row : Gint;
      File_Desc : File_Descriptor;
      Style : array (1 .. Views (Current_View).Num_Columns) of Gtk_Style;
   begin
      if Is_Absolute_Path (Directory_Name) then
         File_Desc := Open_Read (Directory_Name & Directory_Separator
                                 & File_Name & ASCII.Nul, Text);
      else
         File_Desc := Open_Read
           (Get_Current_Dir & Directory_Name & Directory_Separator
            & File_Name & ASCII.Nul, Text);
      end if;

      for Column in Line'Range loop
         if Views (Current_View).Display (Column) /= null then
            Views (Current_View).Display (Column)
              (Viewer, File_Name, Directory_Name, File_Desc,
               Line (Column), Style (Column));
         else
            Line (Column) := New_String ("");
            Style (Column) := null;
         end if;
      end loop;

      Close (File_Desc);

      Row := Append (Viewer.Pages (Current_View), Line);

      for S in Style'Range loop
         Set_Cell_Style
           (Viewer.Pages (Current_View), Row, Gint (S - Style'First),
            Style (S));
      end loop;

      Free (Line);
      return Row;
   end Append_Line_With_Full_Name;

   -----------------
   -- Append_Line --
   -----------------

   procedure Append_Line
     (Viewer : access Project_Viewer_Record'Class;
      Project_View : Project_Id;
      File_Name : String_Id;
      Directory_Filter : Filter := No_Filter)
   is
      Current_View : constant View_Type := Current_Page (Viewer);
      File_N : String (1 .. Integer (String_Length (File_Name)));
      Dir_Name : String_Id;
   begin
      String_To_Name_Buffer (File_Name);
      File_N := Name_Buffer (1 .. Name_Len);
      Dir_Name := Find_In_Source_Dirs (Project_View, File_N);
      pragma Assert (Dir_Name /= No_String);

      if Directory_Filter /= No_Filter
        and then not String_Equal (Directory_Filter, Dir_Name)
      then
         return;
      end if;

      String_To_Name_Buffer (Dir_Name);
      Project_User_Data.Set
        (Viewer.Pages (Current_View),
         Append_Line_With_Full_Name
           (Viewer, Current_View, Project_View,
            File_N, Name_Buffer (1 .. Name_Len)),
         (File_Name => File_Name, Directory => Dir_Name));
   end Append_Line;

   -----------------
   -- Switch_Page --
   -----------------

   procedure Switch_Page
     (Viewer : access Gtk_Widget_Record'Class;
      Args   : Gtk_Args)
   is
      V : Project_Viewer := Project_Viewer (Viewer);
      use type Row_List.Glist;
      Page_Num : constant Guint := To_Guint (Args, 2);
      Current_View : View_Type := View_Type'Val (Page_Num);
      Up_To_Date : View_Type;
      List : Row_List.Glist;
      User : User_Data;
   begin
      --  No current page (happens only while V is not realized)
      if Get_Current_Page (V) = -1 then
         return;
      end if;

      --  Nothing to do if the page is already up-to-date
      if V.Page_Is_Up_To_Date (Current_View) then
         return;
      end if;

      --  Otherwise, we update the list of files based on the contents of
      --  one of the up-to-date pages
      Up_To_Date := View_Type'First;
      loop
         exit when V.Page_Is_Up_To_Date (Up_To_Date);

         --  We haven't found an up-to-date page. This can happen for instance
         --  when Viewer is empty and has never been associated with a
         --  directory before.
         if Up_To_Date = View_Type'Last then
            return;
         end if;
         Up_To_Date := View_Type'Succ (Up_To_Date);
      end loop;

      Freeze (V.Pages (Current_View));
      Clear (V.Pages (Current_View));

      List := Get_Row_List (V.Pages (Up_To_Date));
      while List /= Row_List.Null_List loop
         User := Project_User_Data.Get
           (V.Pages (Up_To_Date), Row_List.Get_Data (List));

         declare
            N : String (1 .. Integer (String_Length (User.File_Name)));
            D : String (1 .. Integer (String_Length (User.Directory)));
         begin
            String_To_Name_Buffer (User.File_Name);
            N := Name_Buffer (1 .. Name_Len);

            String_To_Name_Buffer (User.Directory);
            D := Name_Buffer (1 .. Name_Len);

            Project_User_Data.Set
              (V.Pages (Current_View),
               Append_Line_With_Full_Name
                  (V, Current_View, V.Project_Filter, N, D),
               User);
         end;

         List := Row_List.Next (List);
      end loop;

      Thaw (V.Pages (Current_View));
      V.Page_Is_Up_To_Date (Current_View) := True;
   end Switch_Page;

   ----------------
   -- Select_Row --
   ----------------

   procedure Select_Row
     (Viewer : access Gtk_Widget_Record'Class; Args : Gtk_Args)
   is
      V      : Project_Viewer := Project_Viewer (Viewer);
      Current_View : constant View_Type := Current_Page (V);
      Row    : Gint := To_Gint (Args, 1);
      Column : Gint := To_Gint (Args, 2);
      Event  : Gdk_Event := To_Event (Args, 3);
      User   : User_Data;
      Callback : View_Callback;

   begin
      Callback := Views (Current_View).Callbacks
        (Interfaces.C.size_t (Column + 1));

      --  Event could be null when the row was selected programmatically
      if Event /= null
        and then Get_Event_Type (Event) = Gdk_2button_Press
        and then Callback /= null
      then
         User := Project_User_Data.Get (V.Pages (Current_View), Row);
         Callback (V, Column, User.File_Name, User.Directory);
      end if;
   end Select_Row;

   --------------------------------
   -- Explorer_Selection_Changed --
   --------------------------------

   procedure Explorer_Selection_Changed
     (Viewer : access Gtk_Widget_Record'Class)
   is
      View : Project_Viewer := Project_Viewer (Viewer);
      Current_View : constant View_Type := Current_Page (View);
      Dir, File : String_Id;
      User   : User_Data;
      Rows : Gint;
   begin
      View.Current_Project := Get_Selected_Project (View.Explorer);

      Clear (View);  --  ??? Should delete selectively

      if View.Current_Project /= No_Project then
         Dir := Get_Selected_Directory (View.Explorer);
         Show_Project (View, View.Current_Project, Dir);
      end if;

      File := Get_Selected_File (View.Explorer);
      if File /= No_String then
         Rows := Get_Rows (View.Pages (Current_View));
         for J in 0 .. Rows - 1 loop
            User := Project_User_Data.Get (View.Pages (Current_View), J);

            if User.File_Name = File then
               Select_Row (View.Pages (Current_View), J, 0);
               return;
            end if;
         end loop;
      end if;
   end Explorer_Selection_Changed;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Viewer  : out Project_Viewer;
      Kernel  : access Kernel_Handle_Record'Class;
      Explorer : access Project_Trees.Project_Tree_Record'Class) is
   begin
      Viewer := new Project_Viewer_Record;
      Project_Viewers.Initialize (Viewer, Kernel, Explorer);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Viewer : access Project_Viewer_Record'Class;
      Kernel : access Kernel_Handle_Record'Class;
      Explorer : access Project_Trees.Project_Tree_Record'Class)
   is
      Label : Gtk_Label;
      Color : Gdk_Color;
      Scrolled : Gtk_Scrolled_Window;
   begin
      Gtk.Notebook.Initialize (Viewer);
      Register_Contextual_Menu (Viewer, Viewer_Contextual_Menu'Access);

      Viewer.Kernel := Kernel_Handle (Kernel);
      Viewer.Explorer := Project_Tree (Explorer);

      for View in View_Type'Range loop
         Gtk_New (Scrolled);
         Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
         Gtk_New (Viewer.Pages (View),
                  Columns => Gint (Views (View).Num_Columns),
                  Titles  => Views (View).Titles);
         Add (Scrolled, Viewer.Pages (View));
         Set_Column_Auto_Resize (Viewer.Pages (View), 0, True);
         Gtk_New (Label, Views (View).Tab_Title.all);

         Widget_Callback.Object_Connect
           (Viewer.Pages (View), "select_row",  Select_Row'Access, Viewer);

         Append_Page (Viewer, Scrolled, Label);
      end loop;

      Widget_Callback.Connect (Viewer, "switch_page", Switch_Page'Access);

      Widget_Callback.Object_Connect
        (Explorer, "tree_select_row",
         Widget_Callback.To_Marshaller (Explorer_Selection_Changed'Access),
         Viewer);
      --  Widget_Callback.Object_Connect
      --    (Explorer, "tree_unselect_row",
      --     Widget_Callback.To_Marshaller (Explorer_Selection_Changed'Access),
      --     Viewer);

      Color := Parse (Default_Switches_Color);
      Alloc (Get_Default_Colormap, Color);
      Viewer.Default_Switches_Style := Copy (Get_Style (Viewer));
      Set_Foreground (Viewer.Default_Switches_Style, State_Normal, Color);

      Show_All (Viewer);

      --  The initial contents of the viewer should be read immediately from
      --  the explorer, without forcing the user to do a new selection.
      Explorer_Selection_Changed (Viewer);
   end Initialize;

   ----------------------------
   -- Viewer_Contextual_Menu --
   ----------------------------

   function Viewer_Contextual_Menu
     (Viewer : access Gtk_Widget_Record'Class;
      Event  : Gdk_Event) return Gtk_Menu
   is
      pragma Warnings (Off, Event);
      V : Project_Viewer := Project_Viewer (Viewer);
      Item : Gtk_Menu_Item;
   begin
      if V.Contextual_Menu /= null then
         Destroy (V.Contextual_Menu);
      end if;

      Gtk_New (V.Contextual_Menu);

      Gtk_New (Item, "Edit switches");
      Add (V.Contextual_Menu, Item);

      return V.Contextual_Menu;
   end Viewer_Contextual_Menu;

   ------------------
   -- Current_Page --
   ------------------

   function Current_Page (Viewer : access Project_Viewer_Record'Class)
      return View_Type
   is
      P : Gint := Get_Current_Page (Viewer);
   begin
      if P /= -1 then
         return View_Type'Val (P);
      else
         return View_Type'First;
      end if;
   end Current_Page;

   ------------------
   -- Show_Project --
   ------------------

   procedure Show_Project
     (Viewer              : access Project_Viewer_Record;
      Project_Filter      : Prj.Project_Id;
      Directory_Filter    : Filter := No_Filter)
   is
      Src : String_List_Id := Projects.Table (Project_Filter).Sources;
      Current_View : constant View_Type := Current_Page (Viewer);

   begin
      Viewer.Page_Is_Up_To_Date := (others => False);
      Viewer.Page_Is_Up_To_Date (Current_View) := True;
      Viewer.Project_Filter := Project_Filter;

      Freeze (Viewer.Pages (Current_View));

      while Src /= Nil_String loop
         Append_Line (Viewer, Project_Filter,
                      String_Elements.Table (Src).Value,
                      Directory_Filter);
         Src := String_Elements.Table (Src).Next;
      end loop;

      Thaw (Viewer.Pages (Current_View));
   end Show_Project;

   -----------
   -- Clear --
   -----------

   procedure Clear (Viewer : access Project_Viewer_Record) is
      Current_View : constant View_Type := Current_Page (Viewer);
   begin
      Viewer.Page_Is_Up_To_Date := (others => False);
      Viewer.Page_Is_Up_To_Date (Current_View) := True;

      Freeze (Viewer.Pages (Current_View));
      Clear (Viewer.Pages (Current_View));
      Thaw (Viewer.Pages (Current_View));
   end Clear;

end Project_Viewers;
