-----------------------------------------------------------------------
--                                                                   --
--                     Copyright (C) 2001                            --
--                          ACT-Europe                               --
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

with Gdk.Event;
with Gdk.Window;
with Gtkada.Canvas;

with Src_Info;
with Glide_Kernel;
with Browsers.Canvas;

package Browsers.Dependency_Items is

   ----------------
   -- File items --
   ----------------
   --  These items represent source files from the application.

   type File_Item_Record is new Gtkada.Canvas.Buffered_Item_Record
     with private;
   type File_Item is access all File_Item_Record'Class;

   procedure Gtk_New
     (Item : out File_Item;
      Win  : Gdk.Window.Gdk_Window;
      Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      Dep  : Src_Info.Source_File);
   --  Create a new dependency item that represents Dep.

   procedure Initialize
     (Item : access File_Item_Record'Class;
      Win  : Gdk.Window.Gdk_Window;
      Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      Dep  : Src_Info.Source_File);
   --  Internal initialization function

   procedure On_Button_Click
     (Item  : access File_Item;
      Event : Gdk.Event.Gdk_Event_Button);
   --  Called when the item is clicked on.

   ----------------------
   -- Dependency links --
   ----------------------

   type Dependency_Link_Record is new Gtkada.Canvas.Canvas_Link_Record
     with private;
   type Dependency_Link is access all Dependency_Link_Record'Class;

   procedure Gtk_New
     (Link : out Dependency_Link;
      Dep  : Src_Info.Dependency_Info);
   --  Create a new link.

private
   type File_Item_Record is new Gtkada.Canvas.Buffered_Item_Record
   with record
      Source : Src_Info.Source_File;
      Kernel : Glide_Kernel.Kernel_Handle;

      Browser : Browsers.Canvas.Glide_Browser := null;
      --  Pointer to the parent browser. Note that this is initialized lazily
      --  the first time we need to access this browser.
   end record;

   type Dependency_Link_Record is new Gtkada.Canvas.Canvas_Link_Record
   with record
      Dep : Src_Info.Dependency_Info;
   end record;

end Browsers.Dependency_Items;
