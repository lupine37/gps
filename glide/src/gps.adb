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

with Gtk; use Gtk;
with Gtk.Enums; use Gtk.Enums;
with Gtk.Main;
with Gtk.Rc;
with Glide_Page;
with Glide_Menu;
with Glide_Main_Window;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;          use GNAT.OS_Lib;
with Glide_Kernel;         use Glide_Kernel;
with Glide_Kernel.Help;    use Glide_Kernel.Help;
with Glide_Kernel.Modules; use Glide_Kernel.Modules;
with Glide_Kernel.Project; use Glide_Kernel.Project;
with Gtkada.Intl;          use Gtkada.Intl;
with Gtkada.MDI;           use Gtkada.MDI;
with Gtkada.Dialogs;       use Gtkada.Dialogs;
with GVD.Types;
with OS_Utils;             use OS_Utils;
with Ada.Command_Line;     use Ada.Command_Line;
with Prj;                  use Prj;

--  Modules registered by Glide.
with Aunit_Module;
with Browsers.Dependency_Items;
with Browsers.Projects;
with GVD_Module;
with Metrics_Module;
with Project_Explorers;
with Project_Viewers;
with Src_Editor_Module;
with VCS_Module;
with Vdiff_Module;

procedure Glide2 is
   use Glide_Main_Window;

   subtype String_Access is GNAT.OS_Lib.String_Access;

   Directory_Separator : constant Character := GNAT.OS_Lib.Directory_Separator;
   Glide          : Glide_Window;
   Page           : Glide_Page.Glide_Page;
   Directory      : Dir_Type;
   Str            : String (1 .. 1024);
   Last           : Natural;
   Project_Loaded : Boolean := False;
   Button         : Message_Dialog_Buttons;
   Home           : String_Access;
   Prefix         : String_Access;
   Dir            : String_Access;
   File_Opened    : Boolean := False;

   procedure Init_Settings;
   --  Set up environment for Glide.

   ----------
   -- Init --
   ----------

   procedure Init_Settings is
      Dir_Created : Boolean := False;
   begin
      Home := Getenv ("GLIDE_HOME");

      if Home.all = "" then
         Free (Home);
         Home := Getenv ("HOME");
      end if;

      Prefix := Getenv ("GLIDE_ROOT");

      if Prefix.all = "" then
         Free (Prefix);
         Prefix := new String' (Executable_Location);

         if Prefix.all = "" then
            Free (Prefix);
            Prefix := new String' (GVD.Prefix);
         end if;
      end if;

      Bind_Text_Domain
        ("glide", Prefix.all & GNAT.OS_Lib.Directory_Separator & "share" &
         Directory_Separator & "locale");

      if Home.all /= "" then
         if Is_Directory_Separator (Home (Home'Last)) then
            Dir := new String' (Home (Home'First .. Home'Last - 1) &
              Directory_Separator & ".glide");
         else
            Dir := new String' (Home.all & Directory_Separator & ".glide");
         end if;

      else
         --  Default to /
         Dir := new String'(Directory_Separator & ".glide");
      end if;

      begin
         if not Is_Directory (Dir.all) then
            Make_Dir (Dir.all);
            Button := Message_Dialog
              ((-"Created config directory ") & Dir.all,
               Information, Button_OK, Justification => Justify_Left);
            Dir_Created := True;
         end if;

         if not
           Is_Directory (Dir.all & Directory_Separator & "sessions")
         then
            Make_Dir (Dir.all & Directory_Separator & "sessions");
            if not Dir_Created then
               Button := Message_Dialog
                 ((-"Created config directory ")
                  & Dir.all & Directory_Separator & "sessions",
                  Information, Button_OK, Justification => Justify_Left);
            end if;
         end if;

      exception
         when Directory_Error =>
            Button := Message_Dialog
              ((-"Cannot create config directory ") & Dir.all & ASCII.LF &
               (-"Exiting..."),
               Error, Button_OK,
               Justification => Justify_Left);
            OS_Exit (1);
      end;
   end Init_Settings;

begin
   Aunit_Module.Register_Module;
   VCS_Module.Register_Module;
   Metrics_Module.Register_Module;
   Browsers.Dependency_Items.Register_Module;
   Browsers.Projects.Register_Module;
   Project_Viewers.Register_Module;
   Project_Explorers.Register_Module;
   Src_Editor_Module.Register_Module;
   GVD_Module.Register_Module;
   Vdiff_Module.Register_Module;

   Gtk.Main.Set_Locale;
   Gtk.Main.Init;

   Init_Settings;
   Gtk_New
     (Glide, "<glide>", Glide_Menu.Glide_Menu_Items.all, Dir.all, Prefix.all);
   Set_Title (Glide, "Glide - Next Generation");
   Maximize (Glide);

   declare
      Rc : constant String := Prefix.all & Directory_Separator & "bin" &
        Directory_Separator & "gtkrc";
   begin
      if Is_Regular_File (Rc) then
         Gtk.Rc.Parse (Rc);
      end if;
   end;

   Free (Home);
   Free (Dir);
   Free (Prefix);

   --  ??? Should have a cleaner way of initializing Log_File

   declare
      Log : aliased constant String :=
        Glide.Home_Dir.all & Directory_Separator & "debugger.log" & ASCII.NUL;
   begin
      Glide.Debug_Mode := True;
      Glide.Log_Level  := GVD.Types.Hidden;
      Glide.Log_File   := Create_File (Log'Address, Fmode => Text);
   end;

   Glide_Page.Gtk_New (Page, Glide);
   Initialize_All_Modules (Glide.Kernel);

   for J in 1 .. Argument_Count loop
      if File_Extension (Argument (J)) = Project_File_Extension then
         Load_Project (Glide.Kernel, Argument (J));
         Project_Loaded := True;
      else
         Open_File_Editor (Glide.Kernel, Argument (J));
         File_Opened := True;
      end if;
   end loop;

   --  If no project has been specified on the command line, try to open
   --  the first one in the current directory (if any).

   if not Project_Loaded then
      Open (Directory, Get_Current_Dir);

      loop
         Read (Directory, Str, Last);

         exit when Last = 0;

         if File_Extension (Str (1 .. Last)) = Project_File_Extension then
            Load_Project (Glide.Kernel, Str (1 .. Last));
            exit;
         end if;
      end loop;
   end if;

   if not File_Opened then
      Display_Help
        (Glide.Kernel,
         Glide.Prefix_Directory.all & "/doc/glide2/html/glide-welcome.html");
      Maximize_Children (Get_MDI (Glide.Kernel));
   end if;

   Show_All (Glide);
   Gtk.Main.Main;
end Glide2;
