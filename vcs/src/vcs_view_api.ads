-----------------------------------------------------------------------
--                          G L I D E  I I                           --
--                                                                   --
--                        Copyright (C) 2001                         --
--                            ACT-Europe                             --
--                                                                   --
-- GLIDE is free software; you can redistribute it and/or modify  it --
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

with Glib.Object;   use Glib.Object;
with Glide_Kernel;  use Glide_Kernel;
with Gtk.Menu;      use Gtk.Menu;

package VCS_View_API is

   procedure Open
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Open the selected files.

   procedure Get_Status
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Query status for the selected files.

   procedure Update
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Update the selected files.

   procedure View_Diff
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Launch a visual comparison for the selected files.

   procedure View_Log
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  View the changelog for the selected files.

   procedure View_Annotate
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  View annotations for the selected files.

   procedure Edit_Log
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Launch a log editor for the selected files.

   procedure Commit
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Commit the selected files.

   procedure Add
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Add the selected files to the project repository.

   procedure Remove
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Remove the selected files from the project repository.

   procedure Revert
     (Widget  : access GObject_Record'Class;
      Kernel  : Kernel_Handle);
   --  Revert the selected files.

   procedure VCS_Contextual_Menu
     (Object  : access Glib.Object.GObject_Record'Class;
      Context : access Selection_Context'Class;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Complete Menu with the commands related to the VCS module,
   --  according to the information in Context.

   procedure Open_Explorer
     (Kernel : Kernel_Handle);
   --  If the VCS Explorer is not displayed, display it.

end VCS_View_API;
