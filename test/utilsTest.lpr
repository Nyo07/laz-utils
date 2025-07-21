program utilsTest;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, indylaz, GuiTestRunner, TestUtilsCrypt, RabbitMQTests;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

