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

package body Debugger is

   ------------------
   -- Set_Language --
   ------------------

   procedure Set_Language
     (Debugger     : out Debugger_Root;
      The_Language : Language.Language_Access) is
   begin
      Debugger.The_Language := The_Language;
   end Set_Language;

   ------------------
   -- Get_Language --
   ------------------

   function Get_Language
     (Debugger : Debugger_Root) return Language.Language_Access is
   begin
      return Debugger.The_Language;
   end Get_Language;

   -----------------
   -- Get_Process --
   -----------------

   function Get_Process
     (Debugger : Debugger_Root) return GNAT.Expect.Pipes_Id_Access is
   begin
      return Debugger.Process;
   end Get_Process;

end Debugger;
