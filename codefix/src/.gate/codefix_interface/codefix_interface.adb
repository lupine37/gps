with Gtk; use Gtk;
with Gtk.Main;
with Gtk.Widget; use Gtk.Widget;
with Codefix_Window_Pkg; use Codefix_Window_Pkg;

procedure Codefix_Interface is
   Codefix_Window : Codefix_Window_Access;

begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;
   Gtk_New (Codefix_Window);
   Show_All (Codefix_Window);
   Gtk.Main.Main;
end Codefix_Interface;
