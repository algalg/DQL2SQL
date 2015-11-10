unit DQLProcessor;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  ComObj, ActiveX, MtsObj, Mtx, DQL2SQLLib_TLB, StdVcl;

type
  TDQLProcessor = class(TMtsAutoObject, IDQLProcessor)
  protected
    function ConvertDqlToSql(const SQL: WideString; out TableNames: WideString): WideString; safecall;
  end;

implementation

uses ComServ, gaAdvancedSQLParser, gaBasicSQLParser;

function TDQLProcessor.ConvertDqlToSql(const SQL: WideString; out TableNames: WideString): WideString;
var QueryParser: TgaAdvancedSQLParser;
begin
  QueryParser := TgaAdvancedSQLParser.Create(nil);
  try
    QueryParser.SQLText.Text := Sql;
    QueryParser.Reset;
    while not(QueryParser.TokenType = stEnd) do
      QueryParser.NextToken;

    TableNames := QueryParser.CurrentStatement.TableList;
    result := QueryParser.CurrentStatement.ResultSQL;
  finally
    QueryParser.Free;
  end;
end;

initialization
  TAutoObjectFactory.Create(ComServer, TDQLProcessor, Class_DQLProcessor,
    ciMultiInstance, tmBoth);
end.
