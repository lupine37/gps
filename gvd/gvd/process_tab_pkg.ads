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

with Gtk.Window; use Gtk.Window;
with Gtk.Paned; use Gtk.Paned;
with Gtk.Scrolled_Window; use Gtk.Scrolled_Window;
with Gtk.Notebook; use Gtk.Notebook;
with Gtk.Frame; use Gtk.Frame;
with Gtk.Label; use Gtk.Label;
with Gtk.Text; use Gtk.Text;
with Gtk.Handlers;
with Gtkada.Canvas; use Gtkada.Canvas;
with Gtkada.Code_Editors; use Gtkada.Code_Editors;

package Process_Tab_Pkg is

   type Process_Tab_Record is new Gtk_Window_Record with record
      Notebook_Handler_Id : Gtk.Handlers.Handler_Id;
      Process_Paned : Gtk_Vpaned;
      Vpaned6 : Gtk_Vpaned;
      Scrolledwindow9 : Gtk_Scrolled_Window;
      Data_Canvas : Interactive_Canvas;
      Thread_Notebook : Gtk_Notebook;
      Frame10 : Gtk_Frame;
      Editor_Text : Code_Editor;
      Label52 : Gtk_Label;
      Scrolledwindow7 : Gtk_Scrolled_Window;
      Debugger_Text : Gtk_Text;
   end record;
   type Process_Tab_Access is access all Process_Tab_Record'Class;

   procedure Gtk_New (Process_Tab : out Process_Tab_Access);
   procedure Initialize (Process_Tab : access Process_Tab_Record'Class);

end Process_Tab_Pkg;
