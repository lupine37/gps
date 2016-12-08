------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2016, AdaCore                          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Characters.Handling;     use Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with GNATCOLL.Traces;             use GNATCOLL.Traces;
with GPS.Kernel.Hooks;            use GPS.Kernel.Hooks;
with GPS.Kernel.Project;          use GPS.Kernel.Project;

package body VCS2.Engines is
   Me : constant Trace_Handle := Create ("VCS2");

   Default_Display_Unmodified : constant Status_Display :=
     (Label     => To_Unbounded_String ("Up to date"),
      Icon_Name => To_Unbounded_String ("vcs-up-to-date"));
   Default_Display_Modified : constant Status_Display :=
     (Label     => To_Unbounded_String ("Modified"),
      Icon_Name => To_Unbounded_String ("vcs-modified"));
   Default_Display_Deleted  : constant Status_Display :=
     (Label     => To_Unbounded_String ("Removed"),
      Icon_Name => To_Unbounded_String ("vcs-removed"));
   Default_Display_Deleted_Staged : constant Status_Display :=
     (Label     => To_Unbounded_String ("Deleted (staged)"),
      Icon_Name => To_Unbounded_String ("vcs-removed-staged"));
   Default_Display_Ignored : constant Status_Display :=
     (Label     => To_Unbounded_String ("Ignored"),
      Icon_Name => To_Unbounded_String ("vcs-not-registered"));
   Default_Display_Untracked : constant Status_Display :=
     (Label     => To_Unbounded_String ("Untracked"),
      Icon_Name => To_Unbounded_String ("vcs-unknown"));
   Default_Display_Added : constant Status_Display :=
     (Label     => To_Unbounded_String ("Added"),
      Icon_Name => To_Unbounded_String ("vcs-added"));
   Default_Display_Modified_Staged : constant Status_Display :=
     (Label     => To_Unbounded_String ("Modified (staged)"),
      Icon_Name => To_Unbounded_String ("vcs-modified-staged"));
   Default_Display_Modified_Staged_Unstaged : constant Status_Display :=
     (Label     => To_Unbounded_String ("Modified (staged and unstaged)"),
      Icon_Name => To_Unbounded_String ("vcs-modified-staged-unstaged"));
   Default_Display_Conflict : constant Status_Display :=
     (Label     => To_Unbounded_String ("Conflict"),
      Icon_Name => To_Unbounded_String ("vcs-has-conflicts"));
   Default_Display_Needs_Update : constant Status_Display :=
     (Label     => To_Unbounded_String ("Needs update"),
      Icon_Name => To_Unbounded_String ("vcs-needs-update"));
   Default_Display_Needs_Merge : constant Status_Display :=
     (Label     => To_Unbounded_String ("Needs merge"),
      Icon_Name => To_Unbounded_String ("vcs-needs-merge"));

   package Project_To_Engine is new Ada.Containers.Hashed_Maps
     (Key_Type        => Virtual_File,
      Element_Type    => VCS_Engine_Access,
      Hash            => GNATCOLL.VFS.Full_Name_Hash,
      Equivalent_Keys => "=");
   use Project_To_Engine;

   package Engine_Lists is new Ada.Containers.Doubly_Linked_Lists
     (Element_Type    => VCS_Engine_Access);

   package Name_To_Factory is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => VCS_Engine_Factory_Access,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   use Name_To_Factory;

   function Get_VCS_Factory
     (Kernel   : not null access Kernel_Handle_Record'Class;
      Name     : String)
      return access VCS_Engine_Factory'Class;
   --  Return an engine for the given system (or null)

   procedure Set_VCS
     (Kernel   : not null access Kernel_Handle_Record'Class;
      Location : Virtual_File;
      Engine   : not null VCS_Engine_Access);
   function Get_VCS
     (Kernel  : not null access Kernel_Handle_Record'Class;
      Location : Virtual_File)
      return not null VCS_Engine_Access;

   type Dummy_VCS_Engine is new VCS_Engine with null record;
   overriding function Name
     (Self : not null access Dummy_VCS_Engine) return String is ("unknown");
   overriding procedure Ensure_Status_For_Files
     (Self      : not null access Dummy_VCS_Engine;
      Files     : File_Array;
      Visitor   : access Task_Visitor'Class := null) is null;
   overriding procedure Ensure_Status_For_Project
     (Self      : not null access Dummy_VCS_Engine;
      Project   : Project_Type;
      Visitor   : access Task_Visitor'Class := null) is null;
   overriding procedure Ensure_Status_For_All_Source_Files
     (Self      : not null access Dummy_VCS_Engine;
      Visitor   : access Task_Visitor'Class := null) is null;
   overriding function File_Properties_From_Cache
     (Self    : not null access Dummy_VCS_Engine;
      File    : Virtual_File) return VCS_File_Properties
     is ((Status_Untracked, Null_Unbounded_String, Null_Unbounded_String));
   overriding procedure Stage_Or_Unstage_Files
     (Self    : not null access Dummy_VCS_Engine;
      Files   : GNATCOLL.VFS.File_Array;
      Stage   : Boolean) is null;
   overriding procedure Commit_Staged_Files
     (Self    : not null access Dummy_VCS_Engine;
      Message : String) is null;

   --  An engine that does nothing, used when the project is not setup for
   --  VCS operations

   type Kernel_Data is record
      Factories     : Name_To_Factory.Map;
      All_Engines   : Engine_Lists.List;
      VCS_Engines   : Project_To_Engine.Map;
      No_VCS_Engine : VCS_Engine_Access := new Dummy_VCS_Engine;

      Active_VCS    : VCS_Engine_Access := null;
      --  See the function Active_VCS

   end record;
   Global_Data : Kernel_Data;
   --  Data that will be stored in the kernel, once VCS2 is integrated.
   --  Not done yet to limit the amount of recompiling

   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (VCS_Engine'Class, VCS_Engine_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (VCS_Engine_Factory'Class, VCS_Engine_Factory_Access);
   procedure Unchecked_Free is new Ada.Unchecked_Deallocation
     (VCS_Command'Class, VCS_Command_Access);

   function Need_Update_For_Files
     (Self    : not null access VCS_Engine'Class;
      Sources : File_Array)
      return Boolean;
   --  Return True if any of the files in Sources needs an update of its status
   --  in the cache.
   --  Also mark all files as not needing update, so that multiple calls to
   --  Ensure_Status_* do not result in multiple parallel computation of the
   --  status.

   type Cmd_Ensure_Status_For_Files (Size : Natural) is
      new VCS_Command with record
         Files : File_Array (1 .. Size);
      end record;
   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_Files;
       VCS  : not null access VCS_Engine'Class);
   --  Implementation for Ensure_Status_For_Files

   type Cmd_Ensure_Status_For_Project is new VCS_Command with record
      Project : Project_Type;
   end record;
   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_Project;
       VCS  : not null access VCS_Engine'Class);
   --  Implementation for Ensure_Status_For_Project

   type Cmd_Ensure_Status_For_All_Files is new VCS_Command with null record;
   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_All_Files;
       VCS  : not null access VCS_Engine'Class);
   --  Implementation for Ensure_Status_For_All_Source_Files

   type Cmd_Fetch_History is new VCS_Command with record
      Filter : History_Filter;
   end record;
   overriding procedure Execute
     (Self : not null access Cmd_Fetch_History;
      VCS  : not null access VCS_Engine'Class);
   --  Implementation for Async_Fetch_History

   type Cmd_Fetch_Commit_Details is new VCS_Command with record
      Ids  : String_List_Access;
   end record;
   overriding procedure Execute
     (Self : not null access Cmd_Fetch_Commit_Details;
      VCS  : not null access VCS_Engine'Class);
   overriding procedure Free
     (Self : in out Cmd_Fetch_Commit_Details);

   -------------------
   -- Command queue --
   -------------------

   procedure Queue
     (Self        : not null access VCS_Engine'Class;
      Command     : VCS_Command_Access);
   --  Queue a new command for VCS.
   --  Free Command eventually.

   procedure Complete_Command (Self : not null access VCS_Engine'Class)
     with Pre => not Self.Queue.Is_Empty;
   --  Execute the On_Complete callback for the first command on the queue, if
   --  needed. Then remove the command from the queue.

   procedure Next_In_Queue (Self : not null access VCS_Engine'Class)
     with Pre => Self.Run_In_Background = 0;
   --  Execute the next command in the queue, if any

   procedure Unref (Self : in out Task_Visitor_Access);
   --  Decrease refcount of Self, and free if needed

   type Complete_After_Steps is new Task_Visitor with record
      Wrapped  : not null Task_Visitor_Access;
   end record;
   overriding procedure Free (Self : in out Complete_After_Steps);
   overriding procedure On_Terminate
     (Self  : not null access Complete_After_Steps;
      VCS   : access VCS_Engine'Class);
   --  A wrapper for another visitor, which executes the On_Complete callback
   --  with a null parameter after it has itself completed Steps times.

   ----------
   -- Free --
   ----------

   overriding procedure Free (Self : in out Complete_After_Steps) is
   begin
      Self.Wrapped.On_Terminate (null);
      Unref (Self.Wrapped);
   end Free;

   ------------------
   -- On_Terminate --
   ------------------

   overriding procedure On_Terminate
     (Self  : not null access Complete_After_Steps;
      VCS   : access VCS_Engine'Class) is
   begin
      Self.Wrapped.On_Terminate (VCS);
   end On_Terminate;

   -----------
   -- Unref --
   -----------

   procedure Unref (Self : in out Task_Visitor_Access) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Task_Visitor'Class, Task_Visitor_Access);
   begin
      Self.Refcount := Self.Refcount - 1;
      if Self.Refcount = 0 then
         Self.Free;
         Unchecked_Free (Self);
      end if;
   end Unref;

   ----------------------
   -- Register_Factory --
   ----------------------

   procedure Register_Factory
     (Kernel  : not null access Kernel_Handle_Record'Class;
      Name    : String;
      Factory : not null access VCS_Engine_Factory'Class)
   is
      pragma Unreferenced (Kernel);
      N : constant String := To_Lower (Name);
   begin
      Trace (Me, "Register VCS factory " & N);
      Factory.Name := To_Unbounded_String (N);
      Global_Data.Factories.Include (N, VCS_Engine_Factory_Access (Factory));
   end Register_Factory;

   ---------------------
   -- Get_VCS_Factory --
   ---------------------

   function Get_VCS_Factory
     (Kernel   : not null access Kernel_Handle_Record'Class;
      Name     : String)
      return access VCS_Engine_Factory'Class
   is
      pragma Unreferenced (Kernel);
      C : constant Name_To_Factory.Cursor :=
        Global_Data.Factories.Find (To_Lower (Name));
   begin
      if Has_Element (C) then
         return Element (C);
      else
         return null;
      end if;
   end Get_VCS_Factory;

   -------------
   -- Get_VCS --
   -------------

   overriding function Get_VCS
     (self     : not null access VCS_Repository;
      Project  : Project_Type)
      return not null Abstract_VCS_Engine_Access
     is (Abstract_VCS_Engine_Access
          (Get_VCS (Self.Kernel, Project.Project_Path)));

   -------------
   -- Get_VCS --
   -------------

   function Get_VCS
     (Kernel  : not null access Kernel_Handle_Record'Class;
      Location : Virtual_File)
      return not null VCS_Engine_Access
   is
      C : constant Project_To_Engine.Cursor :=
        Global_Data.VCS_Engines.Find (Location);
   begin
      if Has_Element (C) then
         return Element (C);
      else
         --  for when we use VCS1 and not VCS2. Can be removed eventually
         Global_Data.No_VCS_Engine.Kernel := Kernel_Handle (Kernel);
         return Global_Data.No_VCS_Engine;
      end if;
   end Get_VCS;

   -------------------------
   -- Compute_VCS_Engines --
   -------------------------

   procedure Compute_VCS_Engines
     (Kernel  : not null access Kernel_Handle_Record'Class)
   is
      Dummy : constant Block_Trace_Handle :=
        Create (Me, "Computing VCS repositories for each project");

      function Repo_From_Project
        (F : not null access VCS_Engine_Factory'class;
         P : Project_Type) return Virtual_File;
      --  Guess the repo for a given project.

      function Engine_From_Working_Dir
        (F           : not null access VCS_Engine_Factory'class;
         Working_Dir : Virtual_File) return not null VCS_Engine_Access;
      --  Return the engine to use for a iven repository

      -----------------------------
      -- Engine_From_Working_Dir --
      -----------------------------

      function Engine_From_Working_Dir
        (F           : not null access VCS_Engine_Factory'class;
         Working_Dir : Virtual_File) return not null VCS_Engine_Access
      is
         Engine : VCS_Engine_Access;
      begin
         if Working_Dir = No_File then
            return Global_Data.No_VCS_Engine;
         else
            Engine := Get_VCS (Kernel, Working_Dir);
            if Engine.all in Dummy_VCS_Engine'Class then
               Trace (Me, "  New engine " & Working_Dir.Display_Full_Name);
               Engine := F.Create_Engine (Working_Dir);
               Engine.Set_Working_Directory (Working_Dir);
               Global_Data.All_Engines.Append (Engine);
               Set_VCS (Kernel, Working_Dir, Engine);

               --  if Repo is of the form 'root/.git' or 'root/CVS',... we also
               --  want to register 'root' itself for this VCS even if it does
               --  not contain project sources. This is needed for
               --  Guess_VCS_For_Directory

               if Working_Dir.Is_Directory then
                  Set_VCS (Kernel, Working_Dir.Get_Parent, Engine);
               end if;
            elsif Active (Me) then
               Trace (Me, "  Shared engine " & Working_Dir.Display_Full_Name);
            end if;
            return Engine;
         end if;
      end Engine_From_Working_Dir;

      -----------------------
      -- Repo_From_Project --
      -----------------------

      function Repo_From_Project
        (F : not null access VCS_Engine_Factory'class;
         P : Project_Type) return Virtual_File
      is
         S : File_Array_Access := P.Source_Files (Recursive => False);
      begin
         if S'Length = 0 then
            Unchecked_Free (S);
            return No_File;
         else
            return R : constant Virtual_File :=
              F.Find_Working_Directory (S (S'First))
            do
               Unchecked_Free (S);
            end return;
         end if;
      end Repo_From_Project;

      Iter   : Project_Iterator;
      P      : Project_Type;
      Engine : VCS_Engine_Access;

   begin
      for E of Global_Data.All_Engines loop
         E.In_Use := False;
      end loop;

      Iter := Get_Project (Kernel).Start (Recursive => True);
      loop
         P := Current (Iter);
         exit when P = No_Project;

         Engine := Global_Data.No_VCS_Engine;

         declare
            Kind          : constant String := To_Lower
              (P.Attribute_Value
                 (VCS_Kind_Attribute,
                  Default      => "auto",
                  Use_Extended => True));
            Repo          : constant String := P.Attribute_Value
              (VCS_Repository_Root, Use_Extended => True);
            F             : VCS_Engine_Factory_Access;

         begin
            if Kind /= "auto" then
               Trace (Me, "Using VCS attribute for " & P.Name
                      & " => " & Kind & " " & Repo);
               F := Get_VCS_Factory (Kernel, Kind);
               if F = null then
                  Insert (Kernel, P.Project_Path.Display_Full_Name
                          & ": unknown VCS: " & Kind);
               else
                  Engine := Engine_From_Working_Dir
                    (F,
                     (if Repo /= ""
                      then Create (+Repo)
                      else Repo_From_Project (F, P)));
               end if;

            else
               --  Need to find the closest repo (if for instance we have a
               --  CVS working dir nested in a git working dir, then CVS
               --  should be used). We use the longuest path for this, even if
               --  that won't work for systems using environment variables.

               Trace (Me, "Guessing engine for " & P.Name);
               declare
                  Longuest   : VCS_Engine_Factory_Access;
                  Longuest_R : Virtual_File := No_File;
               begin
                  for F of Global_Data.Factories loop
                     declare
                        R : constant Virtual_File := Repo_From_Project (F, P);
                     begin
                        if R /= No_File
                           and then
                             (Longuest_R = No_File
                              or else Longuest_R.Is_Parent (R))
                        then
                           Longuest_R := R;
                           Longuest := F;
                        end if;
                     end;
                  end loop;

                  if Longuest /= null then
                     Engine := Engine_From_Working_Dir (Longuest, Longuest_R);
                  end if;
               end;
            end if;
         end;

         Set_VCS (Kernel, P.Project_Path, Engine);
         Next (Iter);
      end loop;

      --  Remove all engines that are not used anymore (coming from a previous
      --  project for instance)

      declare
         C  : Engine_Lists.Cursor := Global_Data.All_Engines.First;
         C2 : Engine_Lists.Cursor;
         E  : VCS_Engine_Access;
      begin
         if Global_Data.Active_VCS /= null
           and then not Global_Data.Active_VCS.In_Use
         then
            Global_Data.Active_VCS := null;

            --  Let listeners know: at this point, the VCS is still active, for
            --  views that have cached it.
            Set_Active_VCS (Kernel, Global_Data.All_Engines.First_Element);
         end if;

         while Engine_Lists.Has_Element (C) loop
            C2 := Engine_Lists.Next (C);
            E := Engine_Lists.Element (C);
            if not E.In_Use then
               Trace (Me, "Freeing old engine " & E.Name);
               Free (E.all);
               Unchecked_Free (E);
               Global_Data.All_Engines.Delete (C);
            end if;

            C := C2;
         end loop;

         if Global_Data.Active_VCS = null
           and then not Global_Data.All_Engines.Is_Empty
         then
            Set_Active_VCS (Kernel, Global_Data.All_Engines.First_Element);
         end if;
      end;
   end Compute_VCS_Engines;

   ------------------------------------------------
   -- Ensure_Status_For_All_Files_In_All_Engines --
   ------------------------------------------------

   procedure Ensure_Status_For_All_Files_In_All_Engines
     (Kernel  : not null access Kernel_Handle_Record'Class;
      Visitor : access Task_Visitor'Class := null)
   is
      pragma Unreferenced (Kernel);
      Cb : access Complete_After_Steps;
   begin
      if Visitor /= null then
         Cb := new Complete_After_Steps'
           (Refcount    => Integer (Global_Data.All_Engines.Length),

            --  Unchecked_Access to allow users a call to "new" directly in
            --  the parameter
            Wrapped => Visitor.all'Unchecked_Access);
      end if;

      for E of Global_Data.All_Engines loop
         E.Ensure_Status_For_All_Source_Files (Visitor => Cb);
      end loop;
   end Ensure_Status_For_All_Files_In_All_Engines;

   ---------------------------
   -- Invalidate_All_Caches --
   ---------------------------

   procedure Invalidate_All_Caches
     (Kernel  : not null access Kernel_Handle_Record'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      for E of Global_Data.All_Engines loop
         E.Invalidate_File_Status_Cache;
      end loop;
   end Invalidate_All_Caches;

   ------------------
   -- For_Each_VCS --
   ------------------

   procedure For_Each_VCS
     (Kernel    : not null access Kernel_Handle_Record'Class;
      Callback  : not null access procedure
        (VCS : not null access VCS_Engine'Class))
   is
      pragma Unreferenced (Kernel);
   begin
      for E of Global_Data.All_Engines loop
         Callback (E);
      end loop;
   end For_Each_VCS;

   ---------------
   -- VCS_Count --
   ---------------

   function VCS_Count
     (Kernel   : not null access Kernel_Handle_Record'Class)
      return Natural
   is
      pragma Unreferenced (Kernel);
   begin
      return Natural (Global_Data.All_Engines.Length);
   end VCS_Count;

   -----------------------------
   -- Guess_VCS_For_Directory --
   -----------------------------

   overriding function Guess_VCS_For_Directory
     (Self      : not null access VCS_Repository;
      Directory : Virtual_File) return not null Abstract_VCS_Engine_Access
   is
      VCS : VCS_Engine_Access;
      D   : Virtual_File;
      Dir : Virtual_File := Directory;
   begin
      if Directory /= No_File then
         loop
            VCS := Get_VCS (Self.Kernel, Dir);
            if VCS /= Global_Data.No_VCS_Engine then
               return Abstract_VCS_Engine_Access (VCS);
            end if;
            D := Dir.Get_Parent;

            --  Avoid corner cases, for instance when Dir only contains
            --  file information with no directory
            if D = No_File or else D = Dir then
               exit;
            end if;
            Dir := D;
         end loop;
      end if;

      return Abstract_VCS_Engine_Access (Global_Data.No_VCS_Engine);
   end Guess_VCS_For_Directory;

   -------------
   -- Set_VCS --
   -------------

   procedure Set_VCS
     (Kernel   : not null access Kernel_Handle_Record'Class;
      Location : Virtual_File;
      Engine   : not null VCS_Engine_Access) is
   begin
      Engine.Kernel := Kernel_Handle (Kernel);
      Engine.In_Use := True;
      Global_Data.VCS_Engines.Include (Location, Engine);
   end Set_VCS;

   ----------
   -- Name --
   ----------

   function Name
     (Self : not null access VCS_Engine_Factory'Class) return String is
   begin
      return To_String (Self.Name);
   end Name;

   ---------------------------
   -- Need_Update_For_Files --
   ---------------------------

   function Need_Update_For_Files
     (Self    : not null access VCS_Engine'Class;
      Sources : File_Array)
     return Boolean
   is
      C : VCS_File_Cache.Cursor;
      Need_Update : Boolean := False;
      Default : constant VCS_File_Properties :=
         (Status       => Self.Default_File_Status,
          Version      => Null_Unbounded_String,
          Repo_Version => Null_Unbounded_String);
   begin
      --  Set temporary entry to prevent unneeded parallel computation.
      --  Do not call the hook though, this will be done by Async_Fetch

      for F of Sources loop
         C := Self.Cache.Find (F);
         if F = No_File then
            null;
         elsif not Has_Element (C) then
            Self.Cache.Include (F, (Need_Update => False, Props => Default));
            if not Need_Update and then Active (Me) then
               Trace
                  (Me, "Will fetch status because " & F.Display_Full_Name
                   & " not in cache");
            end if;
            Need_Update := True;

         elsif Element (C).Need_Update then
            Self.Cache.Include
              (F, (Need_Update => False, Props => Element (C).Props));
            if not Need_Update and then Active (Me) then
               Trace
                  (Me, "Will fetch status because " & F.Display_Full_Name
                   & " needs update");
            end if;
            Need_Update := True;
         end if;
      end loop;

      return Need_Update;
   end Need_Update_For_Files;

   ----------------------------
   -- Ensure_Status_For_File --
   ----------------------------

   procedure Ensure_Status_For_Files
     (Self    : not null access VCS_Engine;
      Files   : File_Array;
      Visitor : access Task_Visitor'Class) is
   begin
      Queue (Self,
             new Cmd_Ensure_Status_For_Files'
               (Size    => Files'Length, Files => Files,

                --  Allow callers to pass the result of "new ..." directly
                Visitor =>
                  (if Visitor = null then null
                   else Visitor.all'Unchecked_Access)));
   end Ensure_Status_For_Files;

   overriding procedure Ensure_Status_For_Files
     (Self    : not null access VCS_Engine;
      Files   : File_Array) is
   begin
      Ensure_Status_For_Files (Self, Files, null);
   end Ensure_Status_For_Files;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_Files;
       VCS  : not null access VCS_Engine'Class) is
   begin
      Trace (Me, "Ensure status for a set of files");
      if Need_Update_For_Files (VCS, Self.Files) then
         VCS.Async_Fetch_Status_For_Files (Self.Files);
      end if;
   end Execute;

   -------------------------------
   -- Ensure_Status_For_Project --
   -------------------------------

   procedure Ensure_Status_For_Project
     (Self    : not null access VCS_Engine;
      Project : Project_Type;
      Visitor : access Task_Visitor'Class) is
   begin
      Queue (Self,
             new Cmd_Ensure_Status_For_Project'
               (Project => Project,

                --  Allow callers to pass the result of "new ..." directly
                Visitor =>
                  (if Visitor = null then null
                   else Visitor.all'Unchecked_Access)));
   end Ensure_Status_For_Project;

   overriding procedure Ensure_Status_For_Project
     (Self    : not null access VCS_Engine;
      Project : Project_Type) is
   begin
      Ensure_Status_For_Project (Self, Project, null);
   end Ensure_Status_For_Project;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_Project;
       VCS  : not null access VCS_Engine'Class)
   is
      S : File_Array_Access := Self.Project.Source_Files (Recursive => False);
      N : constant Boolean := Need_Update_For_Files (VCS, S.all);
   begin
      if Active (Me) then
         Trace (Me, "Ensure status for project " & Self.Project.Name
                & " => " & N'Img);
      end if;
      if N then
         VCS.Async_Fetch_Status_For_Project (Self.Project);
      end if;
      Unchecked_Free (S);
   end Execute;

   ----------------------------------------
   -- Ensure_Status_For_All_Source_Files --
   ----------------------------------------

   procedure Ensure_Status_For_All_Source_Files
     (Self    : not null access VCS_Engine;
      Visitor : access Task_Visitor'Class := null) is
   begin
      Queue (Self,
             new Cmd_Ensure_Status_For_All_Files'
               (Visitor =>
                  (if Visitor = null then null
                   else Visitor.all'Unchecked_Access)));
   end Ensure_Status_For_All_Source_Files;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
      (Self : not null access Cmd_Ensure_Status_For_All_Files;
       VCS  : not null access VCS_Engine'Class)
   is
      pragma Unreferenced (Self);
      Iter : Project_Iterator :=
        Get_Project (VCS.Kernel).Start (Recursive => True);
      N    : Boolean := False;
      P    : Project_Type;
      F    : File_Array_Access;
   begin
      Trace (Me, "Ensure status for all source files " & VCS.Name);
      loop
         P := Current (Iter);
         exit when P = No_Project;

         if Get_VCS (VCS.Kernel, P.Project_Path) = VCS then
            --  Need to call this for all projects to initialize table
            F := P.Source_Files (Recursive => False);
            N := Need_Update_For_Files (VCS, F.all) or N;
            Unchecked_Free (F);
         end if;

         Next (Iter);
      end loop;

      if N then
         VCS.Async_Fetch_Status_For_All_Files;
      end if;
   end Execute;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Self : not null access Cmd_Fetch_History;
      VCS  : not null access VCS_Engine'Class)
   is
   begin
      VCS.Async_Fetch_History
        (Visitor => History_Visitor_Access (Self.Visitor),
         Filter  => Self.Filter);
   end Execute;

   -------------------------
   -- Queue_Fetch_History --
   -------------------------

   procedure Queue_Fetch_History
     (Self    : not null access VCS_Engine'Class;
      Visitor : not null access History_Visitor'Class;
      Filter  : History_Filter := No_Filter) is
   begin
      Queue
        (Self,
         new Cmd_Fetch_History'(
           Visitor => Visitor.all'Unchecked_Access,
           Filter  => Filter));
   end Queue_Fetch_History;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Self : not null access Cmd_Fetch_Commit_Details;
      VCS  : not null access VCS_Engine'Class)
   is
   begin
      VCS.Async_Fetch_Commit_Details
        (Self.Ids, History_Visitor_Access (Self.Visitor));
   end Execute;

   ----------
   -- Free --
   ----------

   overriding procedure Free
     (Self : in out Cmd_Fetch_Commit_Details) is
   begin
      Free (Self.Ids);
      Free (VCS_Command (Self));  --  inherited
   end Free;

   --------------------------------
   -- Queue_Fetch_Commit_Details --
   --------------------------------

   procedure Queue_Fetch_Commit_Details
     (Self        : not null access VCS_Engine'Class;
      Ids         : not null GNAT.Strings.String_List_Access;
      Visitor     : not null access History_Visitor'Class) is
   begin
      Queue
        (Self,
         new Cmd_Fetch_Commit_Details'
           (Ids     => Ids,
            Visitor => Visitor.all'Unchecked_Access));
   end Queue_Fetch_Commit_Details;

   ----------------------
   -- Complete_Command --
   ----------------------

   procedure Complete_Command (Self : not null access VCS_Engine'Class) is
      Item : Queue_Item := Self.Queue.First_Element;
   begin
      Item.Command.Free;

      if Item.Command.Visitor /= null then
         Item.Command.Visitor.On_Terminate (Self);
         Unref (Item.Command.Visitor);
      end if;

      Unchecked_Free (Item.Command);

      Self.Queue.Delete_First;
   end Complete_Command;

   -------------------
   -- Next_In_Queue --
   -------------------

   procedure Next_In_Queue
     (Self    : not null access VCS_Engine'Class)
   is
      Item : Queue_Item;
   begin
      if not Self.Queue.Is_Empty then
         Item := Self.Queue.First_Element;
         Item.Command.Execute (Self);

         --  If we haven't started a background command, terminate this
         --  command. Otherwise, wait till Set_Run_In_Background is called.
         --  The queue might have become empty if the command has terminated
         --  immediately (and Set_Run_In_Background has been called).

         if Self.Run_In_Background = 0
           and then not Self.Queue.Is_Empty
         then
            Complete_Command (Self);
            Next_In_Queue (Self);
         end if;
      end if;
   end Next_In_Queue;

   -----------
   -- Queue --
   -----------

   procedure Queue
     (Self        : not null access VCS_Engine'Class;
      Command     : VCS_Command_Access) is
   begin
      --  Allow users to directly pass a "new " as parameter
      Self.Queue.Append ((Command => Command.all'Unchecked_Access));

      if Self.Run_In_Background = 0 then
         Next_In_Queue (Self);
      end if;
   end Queue;

   ---------------------------
   -- Set_Run_In_Background --
   ---------------------------

   procedure Set_Run_In_Background
      (Self       : not null access VCS_Engine'Class;
       Background : Boolean) is
   begin
      if Background then
         Self.Run_In_Background := Self.Run_In_Background + 1;
      else
         Self.Run_In_Background := Self.Run_In_Background - 1;
         Assert (Me, Self.Run_In_Background >= 0, "Invalid Set_In_Background");
         Trace (Me, "Set run in background: " & Self.Run_In_Background'Img);

         --  Queue could be empty if the command was executed directly from
         --  python (and not via a call to Queue).
         if Self.Run_In_Background = 0
           and then not Self.Queue.Is_Empty
         then
            Complete_Command (Self);
            Next_In_Queue (Self);
         end if;
      end if;
   end Set_Run_In_Background;

   --------------------------------
   -- File_Properties_From_Cache --
   --------------------------------

   overriding function File_Properties_From_Cache
     (Self    : not null access VCS_Engine;
      File    : Virtual_File)
      return VCS_File_Properties
   is
      C : constant VCS_File_Cache.Cursor := Self.Cache.Find (File);
   begin
      if Has_Element (C) then
         return Element (C).Props;
      else
         return
            (Status       => VCS_Engine'Class (Self.all).Default_File_Status,
             Version      => Null_Unbounded_String,
             Repo_Version => Null_Unbounded_String);
      end if;
   end File_Properties_From_Cache;

   ----------------------------------
   -- Invalidate_File_Status_Cache --
   ----------------------------------

   procedure Invalidate_File_Status_Cache
     (Self    : not null access VCS_Engine'Class;
      File    : Virtual_File := No_File)
   is
      C : VCS_File_Cache.Cursor;
   begin
      if File = No_File then
         for F of Self.Cache loop
            F.Need_Update := True;
         end loop;

         --  ??? Would be nice to refresh, but we don't know what info
         --  is needed.

      else
         C := Self.Cache.Find (File);
         if Has_Element (C) then
            Self.Cache.Reference (C).Need_Update := True;

            --  Force a refresh immediately in this case since we
            --  know what needs refreshing
            Self.Ensure_Status_For_Files ((1 => File));
         end if;
      end if;
   end Invalidate_File_Status_Cache;

   ------------------------------
   -- Set_File_Status_In_Cache --
   ------------------------------

   overriding procedure Set_File_Status_In_Cache
     (Self         : not null access VCS_Engine;
      File         : Virtual_File;
      Props        : VCS_File_Properties)
   is
      C : constant VCS_File_Cache.Cursor := Self.Cache.Find (File);
      Need_Update : Boolean;
      Need_Hook   : Boolean;
   begin
      if Has_Element (C) then
         Need_Update := Props /= Element (C).Props;
         Need_Hook := Need_Update;
      else
         Need_Update := True;
         Need_Hook := Props.Status /= Self.Default_File_Status
            or else Props.Version /= ""
            or else Props.Repo_Version /= "";
      end if;

      if Need_Update then
         Self.Cache.Include
           (File,
            (Need_Update  => False,
             Props        => Props));

         if Need_Hook then
            Vcs_File_Status_Changed_Hook.Run
              (Self.Kernel,
               Vcs    => Self,
               File   => File,
               Props  => Props);
         end if;
      end if;
   end Set_File_Status_In_Cache;

   -----------------
   -- Get_Display --
   -----------------

   overriding function Get_Display
     (Self   : not null access VCS_Engine;
      Status : VCS_File_Status) return Status_Display
   is
      C : constant VCS_Status_Displays.Cursor := Self.Displays.Find (Status);
      Staged : Boolean;
   begin
      --  Has the VCS defined specific display for this combination of flags ?
      if Has_Element (C) then
         return Element (C);
      else
         --  Fallbacks by looking at a subset of the flags

         Staged := (Status and (Status_Staged_Modified
                                or Status_Staged_Renamed
                                or Status_Staged_Added
                                or Status_Staged_Deleted
                                or Status_Staged_Copied)) /= 0;

         if (Status and Status_Modified) /= 0 then
            if Staged then
               return Default_Display_Modified_Staged_Unstaged;
            elsif (Status and Status_Needs_Update) /= 0 then
               return Default_Display_Needs_Merge;
            else
               return Default_Display_Modified;
            end if;
         elsif (Status and Status_Staged_Added) /= 0 then
            return Default_Display_Added;
         elsif (Status and Status_Staged_Deleted) /= 0 then
            return Default_Display_Deleted_Staged;
         elsif (Status and Status_Deleted) /= 0 then
            return Default_Display_Deleted;
         elsif Staged then
            if (Status and Status_Needs_Update) /= 0 then
               return Default_Display_Needs_Merge;
            else
               return Default_Display_Modified_Staged;
            end if;
         elsif (Status and Status_Untracked) /= 0 then
            return Default_Display_Untracked;
         elsif (Status and Status_Ignored) /= 0 then
            return Default_Display_Ignored;
         elsif (Status and Status_Conflict) /= 0 then
            return Default_Display_Conflict;
         elsif (Status and Status_Needs_Update) /= 0 then
            return Default_Display_Needs_Update;
         else
            return Default_Display_Unmodified;
         end if;
      end if;
   end Get_Display;

   ----------------------
   -- Override_Display --
   ----------------------

   procedure Override_Display
     (Self    : not null access VCS_Engine'Class;
      Status  : VCS_File_Status;
      Display : Status_Display) is
   begin
      Self.Displays.Include (Status, Display);
   end Override_Display;

   --------------
   -- Finalize --
   --------------

   procedure Finalize (Kernel : not null access Kernel_Handle_Record'Class) is
      pragma Unreferenced (Kernel);
      E      : VCS_Engine_Access;
      F2     : VCS_Engine_Factory_Access;
   begin
      Global_Data.VCS_Engines.Clear;

      while not Global_Data.All_Engines.Is_Empty loop
         E := Global_Data.All_Engines.First_Element;
         Free (E.all);
         Unchecked_Free (E);
         Global_Data.All_Engines.Delete_First;
      end loop;

      Free (Global_Data.No_VCS_Engine.all);
      Unchecked_Free (Global_Data.No_VCS_Engine);

      for F of Global_Data.Factories loop
         F2 := F;
         Unchecked_Free (F2);
      end loop;
      Global_Data.Factories.Clear;
   end Finalize;

   --------------------------
   -- Get_Tooltip_For_File --
   --------------------------

   overriding function Get_Tooltip_For_File
     (VCS     : not null access VCS_Engine;
      File    : GNATCOLL.VFS.Virtual_File)
     return String
   is
      V : constant VCS_Engine_Access := VCS_Engine_Access (VCS);
      Props : constant VCS_File_Properties :=
         VCS.File_Properties_From_Cache (File);
   begin
      if Props.Status /= Status_Untracked then
         return "<b>" & V.Name & " status</b>: "
           & To_String (V.Get_Display (Props.Status).Label)
           & (if Props.Version /= ""
              then ASCII.LF & "<b>" & V.Label_Version & "</b>: "
                 & To_String (Props.Version)
              else "")
           & (if Props.Repo_Version /= ""
              then ASCII.LF & "<b>" & V.Label_Repo_Version & "</b>: "
                 & To_String (Props.Repo_Version)
              else "");
      else
         return "";
      end if;
   end Get_Tooltip_For_File;

   ----------------------------
   -- For_Each_File_In_Cache --
   ----------------------------

   procedure For_Each_File_In_Cache
     (Self     : not null access VCS_Engine'Class;
      Callback : not null access procedure
        (File  : GNATCOLL.VFS.Virtual_File;
         Props : VCS_File_Properties))
   is
      C : VCS_File_Cache.Cursor := Self.Cache.First;
   begin
      while VCS_File_Cache.Has_Element (C) loop
         Callback (VCS_File_Cache.Key (C),
                   VCS_File_Cache.Element (C).Props);
         VCS_File_Cache.Next (C);
      end loop;
   end For_Each_File_In_Cache;

   ---------------------------
   -- Set_Working_Directory --
   ---------------------------

   procedure Set_Working_Directory
     (Self        : not null access VCS_Engine'Class;
      Working_Dir : Virtual_File)
   is
   begin
      Self.Working_Dir := Working_Dir;
   end Set_Working_Directory;

   ----------------
   -- Active_VCS --
   ----------------

   function Active_VCS
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
      return VCS_Engine_Access
   is
      pragma Unreferenced (Kernel);
   begin
      return Global_Data.Active_VCS;
   end Active_VCS;

   --------------------
   -- Set_Active_VCS --
   --------------------

   procedure Set_Active_VCS
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class;
      VCS    : not null access VCS_Engine'Class)
   is
   begin
      if VCS /= Global_Data.Active_VCS then
         Global_Data.Active_VCS := VCS_Engine_Access (VCS);
         Vcs_Active_Changed_Hook.Run (Kernel);
      end if;
   end Set_Active_VCS;

end VCS2.Engines;
