-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Glib; use Glib;
with Gtk; use Gtk;
with Gtk.Enums;       use Gtk.Enums;
with Gtkada.Types;    use Gtkada.Types;
with Odd.Dialogs.Callbacks; use Odd.Dialogs.Callbacks;
with Callbacks_Odd;   use Callbacks_Odd;
with Gtkada.Handlers; use Gtkada.Handlers;
with Interfaces.C;    use Interfaces.C;
with Interfaces.C.Strings;
with Odd.Types;       use Odd.Types;
with Odd.Process;     use Odd.Process;
with Odd_Intl;        use Odd_Intl;
with Gtk.GEntry;      use Gtk.GEntry;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Main;        use Gtk.Main;
with Gtk.Dialog;      use Gtk.Dialog;
with Gtk.Label;       use Gtk.Label;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Combo;       use Gtk.Combo;
with Gtk.List;        use Gtk.List;
with Gtk.List_Item;   use Gtk.List_Item;
with Gtk.Object;      use Gtk.Object;
with Gtk.Check_Button; use Gtk.Check_Button;

package body Odd.Dialogs is

   pragma Suppress (All_Checks);
   --  Checks are expensive (in code size) and not needed in this package.

   Question_Titles : constant Chars_Ptr_Array :=
     "" + "Choice";
   --  ??? Should be translatable.

   Backtrace_Titles : constant Chars_Ptr_Array :=
     "PC" + "Subprogram" + "Source";
   --  ???  Should be translated through odd.Intl

   type Simple_Entry_Dialog_Record is new Gtk_Dialog_Record with record
      Entry_Field  : Gtk_Combo;
      Was_Canceled : Boolean;
      Label        : Gtk_Label;
   end record;
   type Simple_Entry_Dialog_Access is access
     all Simple_Entry_Dialog_Record'Class;

   type Display_Dialog_Record is new Simple_Entry_Dialog_Record with record
      Check : Gtk_Check_Button;
   end record;
   type Display_Dialog_Access is access all Display_Dialog_Record'Class;

   package Dialog_User_Data is new Gtk.Object.User_Data
     (Simple_Entry_Dialog_Access);

   procedure Initialize
     (Dialog      : access Odd_Dialog_Record'Class;
      Title       : String;
      Main_Window : Gtk_Window);
   --  Create a standard dialog.

   procedure Cancel_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class);
   --  "Cancel" was pressed in a simple entry dialog

   function Delete_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class)
     return Boolean;
   --  A simple entry dialog was deleted

   procedure Ok_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class);
   --  "Ok" was pressed in a simple entry dialog

   function Internal_Simple_Entry_Dialog
     (Dialog   : access Simple_Entry_Dialog_Record'Class;
      Must_Initialize : Boolean;
      Parent   : access Gtk.Window.Gtk_Window_Record'Class;
      Extra_Box : Gtk.Check_Button.Gtk_Check_Button := null;
      Title    : String;
      Message  : String;
      Position : Gtk_Window_Position := Win_Pos_Center;
      Key      : String := "") return String;
   --  Internal version of Simple_Entry_Dialog, where Dialog is already
   --  created.

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Task_Dialog : out Task_Dialog_Access;
      Main_Window : Gtk_Window;
      Information : Thread_Information_Array) is
   begin
      Task_Dialog := new Task_Dialog_Record;
      Initialize (Task_Dialog, Main_Window, Information);
   end Gtk_New;

   procedure Gtk_New
     (Backtrace_Dialog : out Backtrace_Dialog_Access;
      Main_Window      : Gtk_Window;
      Backtrace        : Backtrace_Array) is
   begin
      Backtrace_Dialog := new Backtrace_Dialog_Record;
      Initialize (Backtrace_Dialog, Main_Window, Backtrace);
   end Gtk_New;

   procedure Gtk_New
     (Question_Dialog            : out Question_Dialog_Access;
      Main_Window                : Gtk_Window;
      Debugger                   : Debugger_Access;
      Multiple_Selection_Allowed : Boolean;
      Questions                  : Question_Array) is
   begin
      Question_Dialog := new Question_Dialog_Record;
      Initialize (Question_Dialog, Main_Window, Debugger,
                  Multiple_Selection_Allowed, Questions);
   end Gtk_New;

   ------------
   -- Update --
   ------------

   procedure Update
     (Task_Dialog : access Task_Dialog_Record;
      Information : Thread_Information_Array)
   is
      Num_Columns : Thread_Fields;
      Row         : Gint;

   begin
      if Task_Dialog.Scrolledwindow1 /= null then
         Destroy (Task_Dialog.Scrolledwindow1);
         Task_Dialog.Scrolledwindow1 := null;
      end if;

      if Information'Length > 0 then
         Set_Default_Size (Task_Dialog, 400, 200);
         Gtk_New (Task_Dialog.Scrolledwindow1);
         Pack_Start
           (Task_Dialog.Vbox1, Task_Dialog.Scrolledwindow1, True, True, 0);
         Set_Policy
           (Task_Dialog.Scrolledwindow1, Policy_Automatic, Policy_Automatic);

         Num_Columns := Information (Information'First).Num_Fields;
         Gtk_New
           (Task_Dialog.List,
            Gint (Num_Columns),
            Information (Information'First).Information);
         Widget_Callback.Connect
           (Task_Dialog.List,
            "select_row",
            On_Task_List_Select_Row'Access);
         Add (Task_Dialog.Scrolledwindow1, Task_Dialog.List);

         for J in Information'First + 1 .. Information'Last loop
            declare
               Info : Chars_Ptr_Array := Information (J).Information;
               --  ??? workaround a bug in GNAT 3.12p that is fixed in 3.13
            begin
               Row := Append (Task_Dialog.List, Info);
            end;
         end loop;

         Row := Columns_Autosize (Task_Dialog.List);
      end if;

      Show_All (Task_Dialog);
   end Update;

   procedure Update
     (Backtrace_Dialog : access Backtrace_Dialog_Record;
      Backtrace        : Backtrace_Array)
   is
      Temp : Chars_Ptr_Array (0 .. 2);
      Row  : Gint;

   begin
      if Backtrace_Dialog.Scrolledwindow1 /= null then
         Destroy (Backtrace_Dialog.Scrolledwindow1);
         Backtrace_Dialog.Scrolledwindow1 := null;
      end if;

      if Backtrace'Length > 0 then
         Set_Default_Size (Backtrace_Dialog, 400, 200);
         Gtk_New (Backtrace_Dialog.Scrolledwindow1);
         Pack_Start
           (Backtrace_Dialog.Vbox1, Backtrace_Dialog.Scrolledwindow1,
            True, True, 0);
         Set_Policy
           (Backtrace_Dialog.Scrolledwindow1, Policy_Automatic,
            Policy_Automatic);

         Gtk_New (Backtrace_Dialog.List, 3, Backtrace_Titles);
         Widget_Callback.Connect
           (Backtrace_Dialog.List,
            "select_row",
            On_Backtrace_List_Select_Row'Access);
         Add (Backtrace_Dialog.Scrolledwindow1, Backtrace_Dialog.List);

         for J in Backtrace'Range loop
            Temp (0) := Strings.New_String (Backtrace (J).Program_Counter.all);
            Temp (1) := Strings.New_String (Backtrace (J).Subprogram.all);
            Temp (2) := Strings.New_String (Backtrace (J).Source_Location.all);
            Row := Append (Backtrace_Dialog.List, Temp);
            Free (Temp);
         end loop;

         Row := Columns_Autosize (Backtrace_Dialog.List);

         --  Prevent huge windows

         for J in Gint range 0 .. 2 loop
            if Optimal_Column_Width (Backtrace_Dialog.List, J) >
              Max_Column_Width
            then
               Set_Column_Width (Backtrace_Dialog.List, J, Max_Column_Width);
            end if;
         end loop;
      end if;

      Show_All (Backtrace_Dialog);
   end Update;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Dialog      : access Odd_Dialog_Record'Class;
      Title       : String;
      Main_Window : Gtk_Window) is
   begin
      Gtk.Dialog.Initialize (Dialog);
      Dialog.Main_Window := Main_Window;

      Set_Title (Dialog, Title);
      Set_Policy (Dialog, False, True, False);
      Set_Position (Dialog, Win_Pos_Center);
      Set_Default_Size (Dialog, -1, 200);

      Dialog.Vbox1 := Get_Vbox (Dialog);
      Set_Homogeneous (Dialog.Vbox1, False);
      Set_Spacing (Dialog.Vbox1, 0);

      Dialog.Hbox1 := Get_Action_Area (Dialog);
      Set_Border_Width (Dialog.Hbox1, 5);
      Set_Homogeneous (Dialog.Hbox1, True);
      Set_Spacing (Dialog.Hbox1, 5);

      Gtk_New (Dialog.Hbuttonbox1);
      Pack_Start (Dialog.Hbox1, Dialog.Hbuttonbox1, True, True, 0);
      Set_Spacing (Dialog.Hbuttonbox1, 10);
      Set_Child_Size (Dialog.Hbuttonbox1, 85, 27);
      Set_Child_Ipadding (Dialog.Hbuttonbox1, 7, 0);

      Gtk_New (Dialog.Close_Button, -"Close");
      Add (Dialog.Hbuttonbox1, Dialog.Close_Button);
   end Initialize;

   procedure Initialize
     (Task_Dialog : access Task_Dialog_Record'Class;
      Main_Window : Gtk_Window;
      Information : Thread_Information_Array) is
   begin
      Initialize (Task_Dialog, -"Task Status", Main_Window);
      Button_Callback.Connect
        (Task_Dialog.Close_Button, "clicked",
         Button_Callback.To_Marshaller (On_Close_Button_Clicked'Access));
      Update (Task_Dialog, Information);
   end Initialize;

   procedure Initialize
     (Backtrace_Dialog : access Backtrace_Dialog_Record'Class;
      Main_Window      : Gtk_Window;
      Backtrace        : Backtrace_Array) is
   begin
      Initialize (Backtrace_Dialog, -"Call Stack", Main_Window);
      Button_Callback.Connect
        (Backtrace_Dialog.Close_Button, "clicked",
         Button_Callback.To_Marshaller (On_Close_Button_Clicked'Access));
      Update (Backtrace_Dialog, Backtrace);
   end Initialize;

   procedure Initialize
     (Question_Dialog            : access Question_Dialog_Record'Class;
      Main_Window                : Gtk_Window;
      Debugger                   : Debugger_Access;
      Multiple_Selection_Allowed : Boolean;
      Questions                  : Question_Array)
   is
      Temp      : Chars_Ptr_Array (0 .. 1);
      Row       : Gint;
      Width     : Gint;
      OK_Button : Gtk_Button;

   begin
      Initialize (Question_Dialog, "Question", Main_Window);
      Widget_Callback.Connect
        (Question_Dialog.Close_Button, "clicked",
         Widget_Callback.To_Marshaller (On_Question_Close_Clicked'Access));

      Question_Dialog.Debugger := Debugger;

      Gtk_New (Question_Dialog.Scrolledwindow1);
      Pack_Start
        (Question_Dialog.Vbox1, Question_Dialog.Scrolledwindow1,
         True, True, 0);
      Set_Policy
        (Question_Dialog.Scrolledwindow1, Policy_Automatic, Policy_Automatic);

      Gtk_New (OK_Button, -"OK");
      Add (Question_Dialog.Hbuttonbox1, OK_Button);
      Widget_Callback.Connect
        (OK_Button,
         "clicked",
         On_Question_OK_Clicked'Access);

      Gtk_New (Question_Dialog.List, 2, Question_Titles);
      Add (Question_Dialog.Scrolledwindow1, Question_Dialog.List);

      if Multiple_Selection_Allowed then
         Set_Selection_Mode (Question_Dialog.List, Selection_Multiple);
      else
         Set_Selection_Mode (Question_Dialog.List, Selection_Single);
      end if;

      for J in Questions'Range loop
         Temp (0) := Strings.New_String (Questions (J).Choice.all);
         Temp (1) := Strings.New_String (Questions (J).Description.all);
         Row := Append (Question_Dialog.List, Temp);
         Free (Temp);
      end loop;

      Set_Column_Width
        (Question_Dialog.List, 0,
         Optimal_Column_Width (Question_Dialog.List, 0));
      Set_Column_Width
        (Question_Dialog.List, 1,
         Gint'Min (Optimal_Column_Width (Question_Dialog.List, 1),
                   Max_Column_Width));
      Set_Column_Auto_Resize (Question_Dialog.List, 0, True);
      Set_Column_Auto_Resize (Question_Dialog.List, 1, True);

      Width := Optimal_Column_Width (Question_Dialog.List, 0)
        + Optimal_Column_Width (Question_Dialog.List, 1)
        + 20;
      Set_Default_Size (Question_Dialog, Gint'Min (Width, 500), 200);

      Register_Dialog (Convert (Main_Window, Debugger), Question_Dialog);
   end Initialize;

   ----------
   -- Free --
   ----------

   procedure Free (Questions : in out Question_Array) is
   begin
      for Q in Questions'Range loop
         Free (Questions (Q).Choice);
         Free (Questions (Q).Description);
      end loop;
   end Free;

   ----------------------------------
   -- Internal_Simple_Entry_Dialog --
   ----------------------------------

   function Internal_Simple_Entry_Dialog
     (Dialog   : access Simple_Entry_Dialog_Record'Class;
      Must_Initialize : Boolean;
      Parent   : access Gtk.Window.Gtk_Window_Record'Class;
      Extra_Box : Gtk.Check_Button.Gtk_Check_Button := null;
      Title    : String;
      Message  : String;
      Position : Gtk_Window_Position := Win_Pos_Center;
      Key      : String := "") return String
   is
      Button : Gtk_Button;
      Box    : Gtk_Box;
      Vbox   : Gtk_Box;
   begin
      if Must_Initialize then
         Set_Transient_For (Dialog, Parent);
         Set_Modal (Dialog);
         Set_Position (Dialog, Position);
         Return_Callback.Connect
           (Dialog, "delete_event",
            Return_Callback.To_Marshaller (Delete_Simple_Entry'Access));

         Gtk_New_Vbox (Vbox);
         Pack_Start (Get_Vbox (Dialog), Vbox);

         Gtk_New_Hbox (Box);
         Pack_Start (Vbox, Box, Padding => 10);

         Gtk_New (Dialog.Label, Message);
         Set_Justify (Dialog.Label, Justify_Center);
         Pack_Start
           (Box, Dialog.Label, Fill => True, Expand => True, Padding => 10);

         Gtk_New (Dialog.Entry_Field);
         Pack_Start (Box, Dialog.Entry_Field, Padding => 10);
         Disable_Activate (Dialog.Entry_Field);
         Widget_Callback.Object_Connect
           (Get_Entry (Dialog.Entry_Field), "activate",
            Widget_Callback.To_Marshaller (Ok_Simple_Entry'Access),
            Dialog);

         if Extra_Box /= null then
            Gtk_New_Hbox (Box);
            Pack_Start (Vbox, Box);
            Pack_Start (Box, Extra_Box, Padding => 10);
         end if;

         Gtk_New (Button, -"OK");
         Set_USize (Button, 80, -1);
         Pack_Start (Get_Action_Area (Dialog), Button, False, False, 14);
         Set_Flags (Button, Can_Default);
         Widget_Callback.Object_Connect
           (Button, "clicked",
            Widget_Callback.To_Marshaller (Ok_Simple_Entry'Access),
            Dialog);

         Gtk_New (Button, -"Cancel");
         Set_USize (Button, 80, -1);
         Pack_Start (Get_Action_Area (Dialog), Button, False, False, 14);
         Set_Flags (Button, Can_Default);
         Widget_Callback.Object_Connect
           (Button, "clicked",
            Widget_Callback.To_Marshaller (Cancel_Simple_Entry'Access),
            Dialog);

         if Key /= "" then
            Dialog_User_Data.Set
              (Parent, Simple_Entry_Dialog_Access (Dialog), Key);
         end if;
      else
         Set_Text (Dialog.Label, Message);
      end if;

      Set_Title (Dialog, Title);
      Set_Text (Get_Entry (Dialog.Entry_Field), "");
      Dialog.Was_Canceled := False;
      Show_All (Dialog);
      Gtk.Main.Main;

      if Dialog.Was_Canceled then
         if Key = "" then
            Destroy (Dialog);
         else
            Hide (Dialog);
         end if;
         return ASCII.Nul & "";

      else
         declare
            S : constant String := Get_Text (Get_Entry (Dialog.Entry_Field));
            Item : Gtk_List_Item;
         begin
            if S /= "" then
               Gtk_New (Item, S);
               Show (Item);
               Add (Get_List (Dialog.Entry_Field), Item);
            end if;
            if Key = "" then
               Destroy (Dialog);
            else
               Hide (Dialog);
            end if;
            return S;
         end;
      end if;
   end Internal_Simple_Entry_Dialog;

   -------------------------
   -- Simple_Entry_Dialog --
   -------------------------

   function Simple_Entry_Dialog
     (Parent   : access Gtk.Window.Gtk_Window_Record'Class;
      Title    : String;
      Message  : String;
      Position : Gtk_Window_Position := Win_Pos_Center;
      Key      : String := "") return String
   is
      Dialog      : Simple_Entry_Dialog_Access;
      Must_Initialize : Boolean := False;
   begin
      if Key /= "" then
         begin
            Dialog := Dialog_User_Data.Get (Parent, Key);
         exception
            when Gtkada.Types.Data_Error => null;
         end;
      end if;

      if Dialog = null then
         Dialog := new Simple_Entry_Dialog_Record;
         Initialize (Dialog);
         Must_Initialize := True;
      end if;

      return Internal_Simple_Entry_Dialog
        (Dialog, Must_Initialize, Parent, null, Title, Message, Position, Key);
   end Simple_Entry_Dialog;

   -------------------------
   -- Cancel_Simple_Entry --
   -------------------------

   procedure Cancel_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class) is
   begin
      Simple_Entry_Dialog_Access (Simple_Dialog).Was_Canceled := True;
      Gtk.Main.Main_Quit;
   end Cancel_Simple_Entry;

   ---------------------
   -- Ok_Simple_Entry --
   ---------------------

   procedure Ok_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class)
   is
   begin
      Gtk.Main.Main_Quit;
   end Ok_Simple_Entry;

   -------------------------
   -- Delete_Simple_Entry --
   -------------------------

   function Delete_Simple_Entry
     (Simple_Dialog : access Gtk_Widget_Record'Class)
     return Boolean is
   begin
      Simple_Entry_Dialog_Access (Simple_Dialog).Was_Canceled := True;
      Gtk.Main.Main_Quit;
      return False;
   end Delete_Simple_Entry;

   --------------------------
   -- Display_Entry_Dialog --
   --------------------------

   function Display_Entry_Dialog
     (Parent   : access Gtk.Window.Gtk_Window_Record'Class;
      Title    : String;
      Message  : String;
      Position : Gtk_Window_Position := Win_Pos_Center;
      Key      : String := "";
      Is_Func  : access Boolean) return String
   is
      Dialog      : Display_Dialog_Access;
      Must_Initialize : Boolean := False;
   begin
      if Key /= "" then
         begin
            Dialog := Display_Dialog_Access
              (Dialog_User_Data.Get (Parent, Key));
         exception
            when Gtkada.Types.Data_Error => null;
         end;
      end if;

      if Dialog = null then
         Dialog := new Display_Dialog_Record;
         Initialize (Dialog);
         Must_Initialize := True;
         Gtk_New (Dialog.Check, -"Expression is a subprogram call");
      end if;

      declare
         S : constant String := Internal_Simple_Entry_Dialog
           (Dialog, Must_Initialize, Parent, Dialog.Check, Title, Message,
            Position, Key);
         R : Boolean;
      begin
         R := Get_Active (Dialog.Check);
         Is_Func.all := R;
         return S;
      end;
   end Display_Entry_Dialog;

end Odd.Dialogs;
