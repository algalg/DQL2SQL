library DQL2SQL;

uses
  ComServ,
  DQL2SQLLib_TLB in 'DQL2SQLLib_TLB.pas',
  DQLProcessor in 'DQLProcessor.pas' {DQLProcessor: CoClass};

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer,
  DllInstall;

{$R *.TLB}

{$R *.RES}

begin
end.
