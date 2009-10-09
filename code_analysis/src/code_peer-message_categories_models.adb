-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                  Copyright (C) 2008-2009, AdaCore                 --
--                                                                   --
-- GPS is Free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with System.Address_To_Access_Conversions;

with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.Tree_Model.Utils;

package body Code_Peer.Message_Categories_Models is

   package Category_Conversions is
     new System.Address_To_Access_Conversions (Code_Peer.Message_Category);

   --------------------
   -- All_Categories --
   --------------------

   function All_Categories
     (Self : access Message_Categories_Model_Record'Class)
      return Message_Category_Ordered_Sets.Set is
   begin
      return Self.Categories;
   end All_Categories;

   -----------------
   -- Category_At --
   -----------------

   function Category_At
     (Self : access Message_Categories_Model_Record'Class;
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter)
      return Code_Peer.Message_Category_Access
   is
      pragma Unreferenced (Self);

   begin
      return
        Code_Peer.Message_Category_Access
          (Category_Conversions.To_Pointer
               (Gtk.Tree_Model.Utils.Get_User_Data_1 (Iter)));
   end Category_At;

   -----------
   -- Clear --
   -----------

   procedure Clear (Self : access Message_Categories_Model_Record) is
   begin
      Self.Categories.Clear;
   end Clear;

   ----------------------
   -- Create_Tree_Iter --
   ----------------------

   function Create_Tree_Iter
     (Self     : access Message_Categories_Model_Record'Class;
      Category : Code_Peer.Message_Category_Access)
      return Gtk.Tree_Model.Gtk_Tree_Iter
   is
      pragma Unreferenced (Self);

   begin
      if Category /= null then
         return
           Gtk.Tree_Model.Utils.Init_Tree_Iter
             (1,
              Category_Conversions.To_Address
                (Category_Conversions.Object_Pointer (Category)));

      else
         return Gtk.Tree_Model.Null_Iter;
      end if;
   end Create_Tree_Iter;

   --------------
   -- Get_Iter --
   --------------

   overriding function Get_Iter
     (Self : access Message_Categories_Model_Record;
      Path : Gtk.Tree_Model.Gtk_Tree_Path) return Gtk.Tree_Model.Gtk_Tree_Iter
   is
      Indices : constant Glib.Gint_Array := Gtk.Tree_Model.Get_Indices (Path);
      Index   : Natural;
      Current : Message_Category_Ordered_Sets.Cursor := Self.Categories.First;

   begin
      if Indices'Length = 1 then
         Index := Natural (Indices (Indices'First));

         while Index /= 0 loop
            Current := Message_Category_Ordered_Sets.Next (Current);
            Index := Index - 1;
         end loop;

         if Message_Category_Ordered_Sets.Has_Element (Current) then
            return
              Self.Create_Tree_Iter
                (Message_Category_Ordered_Sets.Element (Current));
         end if;
      end if;

      return Gtk.Tree_Model.Null_Iter;
   end Get_Iter;

   --------------
   -- Get_Path --
   --------------

   overriding function Get_Path
     (Self : access Message_Categories_Model_Record;
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter) return Gtk.Tree_Model.Gtk_Tree_Path
   is
      Result  : constant Gtk.Tree_Model.Gtk_Tree_Path :=
                  Gtk.Tree_Model.Gtk_New;
      Index   : Natural := 0;
      Current : Message_Category_Ordered_Sets.Cursor :=
                  Self.Categories.Find (Self.Category_At (Iter));

   begin
      Current := Message_Category_Ordered_Sets.Previous (Current);

      while Message_Category_Ordered_Sets.Has_Element (Current) loop
         Index := Index + 1;
         Current := Message_Category_Ordered_Sets.Previous (Current);
      end loop;

      Gtk.Tree_Model.Append_Index (Result, Glib.Gint (Index));

      return Result;
   end Get_Path;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self       : access Message_Categories_Model_Record'Class;
      Categories : Code_Peer.Message_Category_Sets.Set)
   is

      procedure Process (Position : Code_Peer.Message_Category_Sets.Cursor);

      -------------
      -- Process --
      -------------

      procedure Process (Position : Code_Peer.Message_Category_Sets.Cursor) is
      begin
         Self.Categories.Insert
           (Code_Peer.Message_Category_Sets.Element (Position));
      end Process;

   begin
      Gtkada.Abstract_List_Model.Initialize (Self);
      Categories.Iterate (Process'Access);
   end Initialize;

   ----------------
   -- N_Children --
   ----------------

   overriding function N_Children
     (Self : access Message_Categories_Model_Record;
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter := Gtk.Tree_Model.Null_Iter)
      return Glib.Gint is
   begin
      if Iter = Null_Iter then
         return Glib.Gint (Self.Categories.Length);

      else
         return 0;
      end if;
   end N_Children;

   ----------
   -- Next --
   ----------

   overriding procedure Next
     (Self : access Message_Categories_Model_Record;
      Iter : in out Gtk.Tree_Model.Gtk_Tree_Iter)
   is
      Current : Message_Category_Ordered_Sets.Cursor;

   begin
      Current := Self.Categories.Find (Self.Category_At (Iter));
      Current := Message_Category_Ordered_Sets.Next (Current);

      if Message_Category_Ordered_Sets.Has_Element (Current) then
         Iter :=
           Self.Create_Tree_Iter
             (Message_Category_Ordered_Sets.Element (Current));

      else
         Iter := Gtk.Tree_Model.Null_Iter;
      end if;
   end Next;

   ---------------
   -- Nth_Child --
   ---------------

   overriding function Nth_Child
     (Self   : access Message_Categories_Model_Record;
      Parent : Gtk.Tree_Model.Gtk_Tree_Iter;
      N      : Glib.Gint) return Gtk.Tree_Model.Gtk_Tree_Iter
   is
      pragma Unreferenced (Parent);

      Index   : Natural := Natural (N);
      Current : Message_Category_Ordered_Sets.Cursor := Self.Categories.First;

   begin
      while Index /= 0 loop
         Index := Index - 1;
         Current := Message_Category_Ordered_Sets.Next (Current);
      end loop;

      if Message_Category_Ordered_Sets.Has_Element (Current) then
         return
           Self.Create_Tree_Iter
             (Message_Category_Ordered_Sets.Element (Current));

      else
         return Gtk.Tree_Model.Null_Iter;
      end if;
   end Nth_Child;

   -----------------
   -- Row_Changed --
   -----------------

   procedure Row_Changed
     (Self     : access Message_Categories_Model_Record'Class;
      Category : Code_Peer.Message_Category_Access)
   is
      Iter : constant Gtk.Tree_Model.Gtk_Tree_Iter :=
               Self.Create_Tree_Iter (Category);
      Path : constant Gtk.Tree_Model.Gtk_Tree_Path := Self.Get_Path (Iter);

   begin
      Self.Row_Changed (Path, Iter);
      Gtk.Tree_Model.Path_Free (Path);
   end Row_Changed;

   ------------
   -- Update --
   ------------

   procedure Update (Self : access Message_Categories_Model_Record'Class) is

      procedure Process
        (Position : Code_Peer.Message_Category_Ordered_Sets.Cursor);

      -------------
      -- Process --
      -------------

      procedure Process
        (Position : Code_Peer.Message_Category_Ordered_Sets.Cursor) is
      begin
         Self.Row_Changed
           (Code_Peer.Message_Category_Ordered_Sets.Element (Position));
      end Process;

   begin
      Self.Categories.Iterate (Process'Access);
   end Update;

end Code_Peer.Message_Categories_Models;
