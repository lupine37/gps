with Ada.Text_IO; use Ada.Text_IO;

with Generic_List;
with Language; use Language;

with Codefix.Text_Manager; use Codefix.Text_Manager;
with Codefix.Errors_Parser; use Codefix.Errors_Parser;

package Codefix.Formal_Errors is

   function Should_Be
     (Current_Text : Text_Interface'Class;
      Message      : Error_Message;
      Str_Expected : String;
      Str_Red      : String := "")
      return Extract;
   --  This fonction replace Str_Red by Str_Expected in the current text by
   --  the position specified in the Message. If there is no Str_Red, it
   --  looks for the first word in the position.

   function Wrong_Order
     (Current_Text                : Text_Interface'Class;
      Message                     : Error_Message;
      First_String, Second_String : String)
      return Extract;
   --  Seach the position of the second string from the position specified
   --  in the message to the beginning, and invert the two strings.

   function Expected
     (Current_Text    : Text_Interface'Class;
      Message         : Error_Message;
      String_Expected : String;
      Add_Spaces      : Boolean := True)
      return Extract;
   --  Add the missing keyword into the text.

   function Unexpected
     (Current_Text      : Text_Interface'Class;
      Message           : Error_Message;
      String_Unexpected : String;
      Mode              : String_Mode := Text_Ascii)
      return Extract;
   --  Delete the unexpected string

   function Wrong_Column
     (Current_Text    : Text_Interface'Class;
      Message         : Error_Message;
      Column_Expected : Natural := 0)
      return Extract;
   --  Try re-indent the line

   function With_Clause_Missing
     (Current_Text   : Text_Interface'Class;
      Cursor         : File_Cursor'Class;
      Missing_Clause : String)
      return Extract;
   --  Add the missing clause in the text

   type Case_Type is (Lower, Upper, Mixed);

   function Bad_Casing
     (Current_Text : Text_Interface'Class;
      Cursor       : File_Cursor'Class;
      Correct_Word : String := "";
      Word_Case    : Case_Type := Mixed)
   return Extract;
   --  Re-case the word

   function Not_Referenced
     (Current_Text : Text_Interface'Class;
      Cursor       : File_Cursor'Class;
      Category     : Language_Category;
      Name         : String)
   return Solution_List;
   --  Propose to delete the unit unreferrenced or, in some cases, to add
   --  a pragma 'not referreced'

end Codefix.Formal_Errors;
