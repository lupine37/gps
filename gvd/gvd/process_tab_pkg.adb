-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2001                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
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

with Gtk; use Gtk;
with Gtk.Enums;       use Gtk.Enums;
with Gtkada.Handlers; use Gtkada.Handlers;
with Callbacks_Odd;   use Callbacks_Odd;
with Gdk.Types;       use Gdk.Types;

with Process_Tab_Pkg.Callbacks; use Process_Tab_Pkg.Callbacks;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;
with Gtk.Object; use Gtk.Object;
with Gtkada.Intl;     use Gtkada.Intl;
with GVD.Canvas;      use GVD.Canvas;

package body Process_Tab_Pkg is

   Signals : constant Chars_Ptr_Array :=
     (1 => New_String ("executable_changed"));
   Class_Record : System.Address := System.Null_Address;

procedure Gtk_New (Process_Tab : out Process_Tab_Access) is
begin
   Process_Tab := new Process_Tab_Record;
   Process_Tab_Pkg.Initialize (Process_Tab);
end Gtk_New;

procedure Initialize (Process_Tab : access Process_Tab_Record'Class) is
   pragma Suppress (All_Checks);
begin
   Gtk.Window.Initialize (Process_Tab, Window_Toplevel);
   Initialize_Class_Record (Process_Tab, Signals, Class_Record);

   --  Set_Title (Process_Tab, -"");
   --  Set_Policy (Process_Tab, False, True, False);
   --  Set_Position (Process_Tab, Win_Pos_None);
   --  Set_Modal (Process_Tab, False);

   Gtk_New_Vpaned (Process_Tab.Process_Paned);
   Set_Handle_Size (Process_Tab.Process_Paned, 10);
   Set_Gutter_Size (Process_Tab.Process_Paned, 6);
   Set_Position (Process_Tab.Process_Paned, 500);
   --  Add (Process_Tab, Process_Tab.Process_Paned);

   Gtk_New_Vpaned (Process_Tab.Vpaned6);
   Set_Handle_Size (Process_Tab.Vpaned6, 10);
   Set_Gutter_Size (Process_Tab.Vpaned6, 6);
   Set_Position (Process_Tab.Vpaned6, 200);
   Add (Process_Tab.Process_Paned, Process_Tab.Vpaned6);

   Gtk_New_Hpaned (Process_Tab.Hpaned1);
   Set_Handle_Size (Process_Tab.Hpaned1, 10);
   Set_Gutter_Size (Process_Tab.Hpaned1, 6);
   Set_Position (Process_Tab.Hpaned1, 200);
   Add (Process_Tab.Vpaned6, Process_Tab.Hpaned1);

   Gtk_New (Process_Tab.Scrolledwindow13);
   Set_Policy (Process_Tab.Scrolledwindow13, Policy_Automatic, Policy_Automatic);
   Add (Process_Tab.Hpaned1, Process_Tab.Scrolledwindow13);

   Gtk_New (Process_Tab.Stack_List, 5);
   Set_Selection_Mode (Process_Tab.Stack_List, Selection_Single);
   Set_Shadow_Type (Process_Tab.Stack_List, Shadow_In);
   Set_Show_Titles (Process_Tab.Stack_List, True);
   Set_Column_Width (Process_Tab.Stack_List, 0, 80);
   Set_Column_Width (Process_Tab.Stack_List, 1, 80);
   Set_Column_Width (Process_Tab.Stack_List, 2, 80);
   Set_Column_Width (Process_Tab.Stack_List, 3, 80);
   Set_Column_Width (Process_Tab.Stack_List, 4, 80);
   Set_Events (Process_Tab.Stack_List, 
     Button_Press_Mask or
     Button_Release_Mask);
   Process_Tab.Stack_List_Select_Id := C_List_Callback.Connect
     (Process_Tab.Stack_List, "select_row", On_Stack_List_Select_Row'Access);
   Return_Callback.Object_Connect
     (Process_Tab.Stack_List, "button_press_event", On_Stack_List_Button_Press_Event'Access, Process_Tab);
   Add (Process_Tab.Scrolledwindow13, Process_Tab.Stack_List);

   Gtk_New (Process_Tab.Label101, -("Num"));
   Set_Alignment (Process_Tab.Label101, 0.5, 0.5);
   Set_Padding (Process_Tab.Label101, 0, 0);
   Set_Justify (Process_Tab.Label101, Justify_Center);
   Set_Line_Wrap (Process_Tab.Label101, False);
   Set_Column_Widget (Process_Tab.Stack_List, 0, Process_Tab.Label101);

   Gtk_New (Process_Tab.Label201, -("PC"));
   Set_Alignment (Process_Tab.Label201, 0.5, 0.5);
   Set_Padding (Process_Tab.Label201, 0, 0);
   Set_Justify (Process_Tab.Label201, Justify_Center);
   Set_Line_Wrap (Process_Tab.Label201, False);
   Set_Column_Widget (Process_Tab.Stack_List, 1, Process_Tab.Label201);

   Gtk_New (Process_Tab.Label202, -("Subprogram"));
   Set_Alignment (Process_Tab.Label202, 0.5, 0.5);
   Set_Padding (Process_Tab.Label202, 0, 0);
   Set_Justify (Process_Tab.Label202, Justify_Center);
   Set_Line_Wrap (Process_Tab.Label202, False);
   Set_Column_Widget (Process_Tab.Stack_List, 2, Process_Tab.Label202);

   Gtk_New (Process_Tab.Label203, -("Parameters"));
   Set_Alignment (Process_Tab.Label203, 0.5, 0.5);
   Set_Padding (Process_Tab.Label203, 0, 0);
   Set_Justify (Process_Tab.Label203, Justify_Center);
   Set_Line_Wrap (Process_Tab.Label203, False);
   Set_Column_Widget (Process_Tab.Stack_List, 3, Process_Tab.Label203);

   Gtk_New (Process_Tab.Label204, -("Location"));
   Set_Alignment (Process_Tab.Label204, 0.5, 0.5);
   Set_Padding (Process_Tab.Label204, 0, 0);
   Set_Justify (Process_Tab.Label204, Justify_Center);
   Set_Line_Wrap (Process_Tab.Label204, False);
   Set_Column_Widget (Process_Tab.Stack_List, 4, Process_Tab.Label204);

   Gtk_New (Process_Tab.Scrolledwindow12);
   Set_Policy (Process_Tab.Scrolledwindow12, Policy_Automatic, Policy_Automatic);
   Add (Process_Tab.Hpaned1, Process_Tab.Scrolledwindow12);

   Gtk_New (GVD_Canvas (Process_Tab.Data_Canvas));
   Set_Shadow_Type (Process_Tab.Data_Canvas, Shadow_In);
   Add (Process_Tab.Scrolledwindow12, Process_Tab.Data_Canvas);

   Gtk_New (Process_Tab.Editor_Frame);
   Set_Shadow_Type (Process_Tab.Editor_Frame, Shadow_Etched_In);
   Add (Process_Tab.Vpaned6, Process_Tab.Editor_Frame);

   Gtk_New_Hbox (Process_Tab.Editor_Text, Process_Tab);
   Add (Process_Tab.Editor_Frame, Process_Tab.Editor_Text);

   Gtk_New (Process_Tab.Scrolledwindow7);
   Set_Policy (Process_Tab.Scrolledwindow7, Policy_Never, Policy_Always);
   Add (Process_Tab.Process_Paned, Process_Tab.Scrolledwindow7);

   Gtk_New (Process_Tab.Debugger_Text);
   Set_Editable (Process_Tab.Debugger_Text, True);
   Widget_Callback.Object_Connect
     (Process_Tab.Debugger_Text, "insert_text", On_Debugger_Text_Insert_Text'Access, Process_Tab);
   Process_Tab.Delete_Text_Handler_Id := Widget_Callback.Object_Connect
     (Process_Tab.Debugger_Text, "delete_text", On_Debugger_Text_Delete_Text'Access, Process_Tab);
   Return_Callback.Object_Connect
     (Process_Tab.Debugger_Text, "key_press_event", On_Debugger_Text_Key_Press_Event'Access, Process_Tab);
   Widget_Callback.Object_Connect
     (Process_Tab.Debugger_Text, "grab_focus",
      Widget_Callback.To_Marshaller (On_Debugger_Text_Grab_Focus'Access), Process_Tab);
   Add (Process_Tab.Scrolledwindow7, Process_Tab.Debugger_Text);

end Initialize;

end Process_Tab_Pkg;
