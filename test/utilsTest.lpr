program utilsTest;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, TestUtilsCrypt;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

