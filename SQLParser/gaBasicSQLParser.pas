{*******************************************************}
{                                                       }
{       Basic SQL statement parser                      }
{       Based on Borland's TSQLParser found in          }
{       UpdateSQL editor                                }
{       Copyright (c) 2001 - 2003 AS Gaiasoft           }
{       Created by Gert Kello                           }
{                                                       }
{*******************************************************}

unit gaBasicSQLParser;


{$WARN WIDECHAR_REDUCED OFF}
{$HINTS OFF}

{ To do list: }

{  #ToDo2 How the parameters have to be parsed, and which forms are allowed
          Need to check Delphi source...}
{  #ToDo2 Add statement delimitier/multistatement support (may require support
          for something like "set term ..")
}

interface

uses
  Classes, SysUtils;
type
  TSQLToken = (stSymbol, stQuotedSymbol, stString, stDelimitier, stParameter,
    stNumber, stComment, stComma, stPeriod, stEQ, stLParen, stRParen, stOther,
    stPlaceHolder, stSubStatementEnd, stEnd);
  TSQLTokenTypes = set of TSQLToken;

  SQLParserException = class(Exception);

  TCommentType = (ctMultiLine, ctLineEnd);

  TgaQuoteType = (qtUnknown, qtString, qtSymbol);

  TgaSQLQuoteInfoItem = class (TCollectionItem)
  private
    FEndDelimitier: Char;
    FQuotedIdentifierType: TgaQuoteType;
    FStartDelimitier: Char;
  published
    property EndDelimitier: Char read FEndDelimitier write FEndDelimitier;
    property QuotedIdentifierType: TgaQuoteType read FQuotedIdentifierType
            write FQuotedIdentifierType;
    property StartDelimitier: Char read FStartDelimitier write FStartDelimitier;
  end;
  
  TgaSQLQuoteInfoCollection = class (TOwnedCollection)
  private
    function GetItem(Index: Integer): TgaSQLQuoteInfoItem;
    procedure SetItem(Index: Integer; const Value: TgaSQLQuoteInfoItem);
  public
    constructor Create(AOwner: TPersistent);
    function Add: TgaSQLQuoteInfoItem;
    function Insert(Index: Integer): TgaSQLQuoteInfoItem;
    property Items[Index: Integer]: TgaSQLQuoteInfoItem read GetItem write 
            SetItem;
  end;
  
  TgaBasicSQLParser = class (TComponent)
  private
    FCurrentPos: PChar;
    FEndQuote: Char;
    FOnTokenParsed: TNotifyEvent;
    FSourcePtr: PChar;
    FSQLText: TStrings;
    FStartQuote: Char;
    FSymbolQuotes: TgaSQLQuoteInfoCollection;
    FText: string;
    FToken: TSQLToken;
    FTokenEnd: PChar;
    FTokenQuoted: Boolean;
    FTokenStart: PChar;
    FTokenString: string;
    FProcessingFolder : boolean;
    FIsDistinct : boolean;
    FProcessingCabinet : boolean;
    FProcessingAny : boolean;
    FInAfterAny : boolean;
    FHaveMetLastBracket : boolean;
    FStopProcessingAny : boolean;
    FProcessingAnyString : string;
    FIDSpecified : boolean;
    FProcessingExactFolder : boolean;
    procedure SetSQLText(const Value: TStrings);
    procedure SetSymbolQuotes(const Value: TgaSQLQuoteInfoCollection);
    procedure SetText(const Value: string);
  protected
    procedure DoTokenParsed; virtual;
    function FindQuoteInfoForChar(AChar: Char): TgaSQLQuoteInfoItem;
    function IsStartQuote(AChar: Char): Boolean;
    function ScanComment(CommentType: TCommentType): TSQLToken;
    function ScanDelimitier: TSQLToken;
    function ScanNumber: TSQLToken;
    function ScanOther: TSQLToken;
    function ScanParam: TSQLToken;
    function ScanQuotedtSymbol: TSQLToken;
    function ScanSpecial: TSQLToken;
    function ScanSymbol: TSQLToken;
    procedure SQLTextChanged(Sender: TObject);
    function TokenSymbolIs(const S: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function NextToken: TSQLToken;
    procedure Reset; virtual;
    property EndQuote: Char read FEndQuote;
    property StartQuote: Char read FStartQuote;
    property Text: string read FText write SetText;
    property TokenQuoted: Boolean read FTokenQuoted write FTokenQuoted ;
    property TokenString: string read FTokenString;
    property TokenType: TSQLToken read FToken;
  published
    property OnTokenParsed: TNotifyEvent read FOnTokenParsed write
            FOnTokenParsed;
    property SQLText: TStrings read FSQLText write SetSQLText;
    property SymbolQuotes: TgaSQLQuoteInfoCollection read FSymbolQuotes write
            SetSymbolQuotes;
  end;


  
implementation

// Delphi5 does not have MSWINDOWS defined...
{$ifdef Win32}
{$define MSWINDOWS}
{$endif}

uses
  {$ifdef MSWINDOWS}Windows{$endif}, gaSQLParserConsts;

function IsKatakana(const Chr: Byte): Boolean;
begin
  {$ifdef MSWINDOWS}
  Result := (SysLocale.PriLangID = LANG_JAPANESE) and (Chr in [$A1..$DF]);
  {$endif}
  {$ifdef LINUX}
  Result := False;
  {$endif}
  // #ToDo1 quick dirty solution for Kylix
end;

{
****************************** TgaBasicSQLParser *******************************
}
constructor TgaBasicSQLParser.Create(AOwner: TComponent);
begin
  inherited;
  FSQLText := TStringList.Create;
  TStringList(FSQLText).OnChange := SQLTextChanged;
  FSymbolQuotes := TgaSQLQuoteInfoCollection.Create(Self);
  with FSymbolQuotes.Add as TgaSQLQuoteInfoItem do
  begin
    StartDelimitier := '"';
    EndDelimitier := '"';
    QuotedIdentifierType := qtSymbol;
  end;
  with FSymbolQuotes.Add as TgaSQLQuoteInfoItem do
  begin
    StartDelimitier := '''';
    EndDelimitier := '''';
    QuotedIdentifierType := qtString;
  end;
end;

destructor TgaBasicSQLParser.Destroy;
begin
  TStringList(FSQLText).OnChange := nil;
  FSQLText.Free;
  FSymbolQuotes.Free;
  inherited;
end;

procedure TgaBasicSQLParser.DoTokenParsed;
begin                          
  if Assigned(FOnTokenParsed) then
    FOnTokenParsed(self);
end;

function TgaBasicSQLParser.FindQuoteInfoForChar(AChar: Char):
        TgaSQLQuoteInfoItem;
var
  i: Integer;
begin
  for i := 0 to FSymbolQuotes.Count - 1 do
  begin
    Result := FSymbolQuotes.Items[i] as TgaSQLQuoteInfoItem;
    if Result.StartDelimitier = AChar then
      Exit;
  end;
  Result := nil;
end;

function TgaBasicSQLParser.IsStartQuote(AChar: Char): Boolean;
begin
  Result := FindQuoteInfoForChar(AChar) <> nil;
end;

function TgaBasicSQLParser.NextToken: TSQLToken;
var
 s_TempFolder, s_TempFolderID, s_TempAny, s_TempCabinet : string;
 s_TableName, s_Alias : string;
 i_Pos1, i_Pos2, i_PosSpace, i_PosDot : integer;
begin
  // No need for the "I_HAS_FOLDER = 1" here. The view will take care of what can/cannot be seem. i.e. previous versions or not 
  s_TempFolder := 'SELECT ''n'' FROM QM_FOLDER_R WHERE R_OBJECT_ID = I_FOLDER_ID AND R_FOLDER_PATH LIKE ''%s''';
  s_TempFolderID := 'SELECT ''n'' FROM QM_FOLDER_R WHERE R_OBJECT_ID = I_FOLDER_ID AND LINK_FROM_ID = ''%s''';
  s_TempAny := ' (SELECT ''n'' FROM %s_R WHERE %s.R_OBJECT_ID = LINK_FROM_ID AND %s) ';

  if FToken = stEnd then
    SysUtils.Abort;
  FTokenString := '';
  FTokenQuoted := False;
  FStartQuote := ' ';
  FEndQuote := ' ';
  FCurrentPos := FSourcePtr;
  FTokenStart := FSourcePtr;
  FTokenEnd := nil;
  case FCurrentPos^ of
    #01..' ':
      FToken := ScanDelimitier;
    ':':
      if (FCurrentPos+1)^ = ':' then
        FToken := ScanSymbol //actually BDE alias
      else
        FToken := ScanParam;
    'A'..'Z', 'a'..'z', '_', '$', #127..#255:
      FToken := ScanSymbol;
    '0'..'9':
      FToken := ScanNumber;
    '/':
      if (FCurrentPos+1)^ in ['*', '/'] then
        // ((P+1)^ = '/') = True; Ord(True) = 1; TCommnetType(1) = ctLineEnd;
        FToken := ScanComment(TCommentType(Ord((FCurrentPos+1)^ = '/')))
      else
        FToken := ScanOther;
    ',', '=', '(', ')', '.':
      FToken := ScanSpecial;
    #0:
      FToken := stEnd;
    else
      if (FCurrentPos^ = '-') and ((FCurrentPos+1)^ = '-') then
        FToken := ScanComment(ctLineEnd)
      else if IsStartQuote(FCurrentPos^) then
        FToken := ScanQuotedtSymbol
      else
        FToken := ScanOther;
  end;
  FSourcePtr := FCurrentPos;
  if FTokenEnd = nil then
    FTokenEnd := FCurrentPos;
  SetString(FTokenString, FTokenStart, FTokenEnd - FTokenStart);

  // Replace 'i_vstamp' with 'versionstamp' - helps to make it more compatible with Documentum queries
  if (UpperCase(FTokenString) = 'I_VSTAMP') and (FToken = stSymbol) then
    FTokenString := 'versionstamp';

  // Processing for FOLDER predicate
  if (UpperCase(FTokenString) = 'FOLDER') and (FToken = stSymbol) then
  begin
    FTokenString := 'EXISTS';
    FProcessingFolder := true;
  end;

  // We have a DISTINCT specified
  if (UpperCase(FTokenString) = 'DISTINCT') and (FToken = stSymbol) and (FIsDistinct = False) then
    FIsDistinct := true;

  // Processing for CABINET predicate
  if (UpperCase(FTokenString) = 'CABINET') and (FToken = stSymbol) then
  begin
    FTokenString := 'EXISTS';
    FProcessingFolder := true;
    FProcessingCabinet := true;
  end;

  // The ExactFolder token doesn't need a final %
  if (UpperCase(FTokenString) = 'EXACTFOLDER') and (FToken = stSymbol) then
  begin
    FTokenString := 'EXISTS';
    FProcessingFolder := true;
    FProcessingExactFolder := true;
  end;


  // Check to see if the ID function has been specified and we are not processing a "folder" fucntion.
  // This is only applicable to SQL Server as UDF's have to be prefixed with 'dbo.' in SQL Server
  if (not FProcessingFolder) and (UpperCase(FTokenString) = 'ID') and (FToken = stSymbol) then
    FTokenString := '';


  // Check to see if the ID function has been specified
  if (FProcessingFolder) and (UpperCase(FTokenString) = 'ID') and (FToken = stSymbol) then
  begin
    FIDSpecified := true;
    FTokenString := '';
  end;

  // If we are dealing with the FOLDER function and we encounter quotes then don't process then
  if FProcessingFolder and (FToken = stString) then
    TokenQuoted := False;

  // Check to see if we have out folder path or folder id parsed
  if ((FProcessingFolder) and (FToken = stString)) or ((FProcessingFolder) and (FToken = stRParen)) then
  begin
    if (FTokenString = '') or (FToken = stRParen) then
      raise SQLParserException.Create('A location has not been specified for the FOLDER predicate.');

    if FIDSpecified then
       FTokenString := format(s_TempFolderID, [FTokenString])
    else
    begin
      // Don't want a '%' for the like comparison for cabinets
      // and also for ExactFolder token
      if not FProcessingCabinet then
        if Not FProcessingExactFolder then
          FTokenString := FTokenString + '%';
      FTokenString := format(s_TempFolder, [FTokenString]); // rhy maybe remove the % when we iron things out

    end;
    FProcessingFolder := False;
    if FProcessingExactFolder Then
      FProcessingExactFolder := False;

    if FProcessingCabinet then
    begin
      FTokenString := FTokenString + s_TempCabinet;
      FProcessingCabinet := false;
    end;

    FIDSpecified := False;
  end;

  // If FProcessingAny and we encounter and IN then don't FStopProcessingAny until we meet a closed set of brackets
  if (UpperCase(FTokenString) = 'IN') and (FToken = stSymbol) and FProcessingAny then
    FInAfterAny := True;

  // Have we met a ')' in after the ANY statement
  if FInAfterAny and (FTokenString = ')') and (FToken = stRParen) then
    FHaveMetLastBracket := True;

  // See if we have to stop processing the ANY stuff (where an IN was specified)
  if FProcessingAny and not FInAfterAny then
  begin
    if (FTokenString = ';') and (FToken = stOther) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'AND') and (FToken = stSymbol) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'OR') and (FToken = stSymbol) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'ORDER') and (FToken = stSymbol) then
      FStopProcessingAny := true;
  end;

  // See if we have to stop processing the ANY stuff (where an IN was not specified)
  if FProcessingAny and FInAfterAny and FHaveMetLastBracket then
  begin
    if (FTokenString = ';') and (FToken = stOther) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'AND') and (FToken = stSymbol) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'OR') and (FToken = stSymbol) then
      FStopProcessingAny := true;

    if (UpperCase(FTokenString) = 'ORDER') and (FToken = stSymbol) then
      FStopProcessingAny := true;
  end;


  // Processing for ANY predicate
  if (UpperCase(FTokenString) = 'ANY') and (FToken = stSymbol) then
  begin
    FTokenString := 'EXISTS';
      FProcessingAny := True;
    FProcessingAnyString := '';
    FStopProcessingAny := False;
  end
  else
  begin
    if (FProcessingAny = true) and (FStopProcessingAny = false) then
    begin
      if TokenQuoted then
        FProcessingAnyString := FProcessingAnyString + '''' + FTokenString + ''''
      else
        FProcessingAnyString := FProcessingAnyString + FTokenString;

      FTokenString := 'skip';
    end
    else if (FProcessingAny = true) and (FStopProcessingAny = true) then
    begin
      i_Pos1 := Pos('(', FProcessingAnyString);
      i_Pos2 := Pos(')', FProcessingAnyString);

      s_TableName := trim(Copy(FProcessingAnyString, i_Pos1 + 1, i_Pos2 - i_Pos1 - 1));
      // Strip out any single-quotes specified in the
      s_TableName := StringReplace(s_TableName, '''', '', [rfReplaceAll]);
      // if the user has not specified a table name for the ANY predicate then raise an error
      if s_TableName = '' then
        raise SQLParserException.Create('A table name has not been specified for the ANY predicate.');

      // Check is the table has an alias specified. If so the strip out the table name and the alias.
      i_PosSpace := Pos(' ', s_TableName);
      if i_PosSpace = 0 then
        s_Alias := s_TableName
      else
      begin
        s_Alias := trim(Copy(s_TableName, i_PosSpace, length(s_TableName)));
        s_TableName := trim(Copy(s_TableName, 1, i_PosSpace));
      end;

      // convert the table name and alias to upper case
      s_TableName := UpperCase(s_TableName);
      s_Alias := UpperCase(s_Alias);

      // Check and see if an alias has been specified in front of the repeating attribute field.
      // If it has then remove it as it will cause the EXISTS query to fail
      FProcessingAnyString := trim(Copy(FProcessingAnyString, i_Pos2 + 1, length(FProcessingAnyString)));
      i_PosSpace := Pos(' ', FProcessingAnyString);
      i_PosDot := Pos('.', FProcessingAnyString);
      if i_PosDot < i_PosSpace then
        FProcessingAnyString := Copy(FProcessingAnyString, i_PosDot + 1, length(FProcessingAnyString));

      // Format the query using the values extracted above
      FTokenString := format(s_TempAny, [s_TableName, s_Alias, FProcessingAnyString]) + FTokenString;
      FProcessingAny := False;
    end;
  end;

  Result := FToken;
  DoTokenParsed;
end;

procedure TgaBasicSQLParser.Reset;
begin
  FText := trim(FText);
  // If the SQL statement does not have a ';' then add it as it is need to parse the statement properly
  if Copy(FText, length(FText) , 1) <> ';' then
    FText := FText + ';';
  FSourcePtr := PChar(FText);
  FToken := stSymbol;
  FStopProcessingAny := True;
  NextToken;
end;

function TgaBasicSQLParser.ScanComment(CommentType: TCommentType): TSQLToken;
begin
  Inc(FCurrentPos, 2); // every comment starts with doublechar comment identifier
  if CommentType = ctLineEnd then
    while not (FCurrentPos^ in [#10, #13]) do
      Inc(FCurrentPos)
  else
    while not (((FCurrentPos-1)^ = '/') and ((FCurrentPos-2)^ = '*')) do
      Inc(FCurrentPos);
  Result := stComment;
end;

function TgaBasicSQLParser.ScanDelimitier: TSQLToken;
begin
  while (FCurrentPos^ in [#01..' ']) do
    Inc(FCurrentPos);
  Result := stDelimitier;
end;

function TgaBasicSQLParser.ScanNumber: TSQLToken;
begin
  Inc(FCurrentPos);
  while FCurrentPos^ in ['0'..'9', '.', 'e', 'E', '+', '-'] do
    Inc(FCurrentPos);
  Result := stNumber;
end;

function TgaBasicSQLParser.ScanOther: TSQLToken;
begin
  Inc(FCurrentPos);
  Result := stOther;
end;

function TgaBasicSQLParser.ScanParam: TSQLToken;
begin
  Inc(FCurrentPos);
  FTokenStart := FCurrentPos;
  case FCurrentPos^ of
    #0..' ', ',':
      FTokenEnd := FCurrentPos;
    '''', '"':
      ScanQuotedtSymbol;
    else
  //    '0'..'9', 'A'..'Z', 'a'..'z', '_', '$', #127..#255:
      ScanSymbol;
  end;
  Result := stParameter;
end;

function TgaBasicSQLParser.ScanQuotedtSymbol: TSQLToken;
var
  QuoteInfo: TgaSQLQuoteInfoItem;
begin
  FStartQuote := FCurrentPos^;
  QuoteInfo := FindQuoteInfoForChar(FStartQuote);
  Assert(QuoteInfo <> nil);
  if QuoteInfo.QuotedIdentifierType = qtUnknown then
    raise Exception.CreateFmt('The type of quote %s<text>%s is unknown',  [QuoteInfo.StartDelimitier, QuoteInfo.EndDelimitier]);
  Inc(FCurrentPos);
  FTokenStart := FCurrentPos;
  while not (FCurrentPos^ in [QuoteInfo.EndDelimitier, #0]) do
    Inc(FCurrentPos);
  if FCurrentPos^ = #0 then
    raise Exception.CreateFmt('No end quote (%s) found in SQL text for start quote (%s)', [QuoteInfo.EndDelimitier, QuoteInfo.StartDelimitier]);
  FEndQuote := FCurrentPos^;
  FTokenEnd := FCurrentPos;
  Inc(FCurrentPos);
  FTokenQuoted := True;
  if QuoteInfo.QuotedIdentifierType = qtSymbol then
    Result := stQuotedSymbol
  else
    Result := stString;
end;

function TgaBasicSQLParser.ScanSpecial: TSQLToken;
begin
  case FCurrentPos^ of
    ',':
      Result := stComma;
    '=':
      Result := stEQ;
    '(':
      Result := stLParen;
    ')':
      Result := stRParen;
    '.':
      Result := stPeriod;
    else
      raise Exception.CreateFmt(SWrongSpecialChar, [FCurrentPos^]);
  end;
  inc(FCurrentPos);
end;

function TgaBasicSQLParser.ScanSymbol: TSQLToken;
begin
  if not SysLocale.FarEast then
  begin
    Inc(FCurrentPos);
    while FCurrentPos^ in ['A'..'Z', 'a'..'z', '0'..'9', '_', '"', '$', #127..#255] do
      Inc(FCurrentPos);
  end
  else begin
    while TRUE do
    begin
      if (FCurrentPos^ in ['A'..'Z', 'a'..'z', '0'..'9', '_', '"', '$']) or
         IsKatakana(Byte(FCurrentPos^)) then
        Inc(FCurrentPos)
      else
        if FCurrentPos^ in LeadBytes then
          Inc(FCurrentPos, 2)
        else
          Break;
    end;
  end;
  Result := stSymbol;
end;

procedure TgaBasicSQLParser.SetSQLText(const Value: TStrings);
begin
  FSQLText.Assign(Value);
end;

procedure TgaBasicSQLParser.SetSymbolQuotes(const Value: 
        TgaSQLQuoteInfoCollection);
begin
  FSymbolQuotes.Assign(Value);
end;

procedure TgaBasicSQLParser.SetText(const Value: string);
begin
  if FText <> Value then
  begin
    FText := Value;
    Reset;
  end;
end;

procedure TgaBasicSQLParser.SQLTextChanged(Sender: TObject);
begin
  Text := FSQLText.Text;
end;

function TgaBasicSQLParser.TokenSymbolIs(const S: string): Boolean;
begin
  Result := (FToken = stSymbol) and (CompareText(FTokenString, S) = 0);
end;

{ TgaSQLQuoteInfoCollection }

{
************************** TgaSQLQuoteInfoCollection ***************************
}
constructor TgaSQLQuoteInfoCollection.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TgaSQLQuoteInfoItem);
end;

function TgaSQLQuoteInfoCollection.Add: TgaSQLQuoteInfoItem;
begin
  Result := TgaSQLQuoteInfoItem(inherited Add);
end;

function TgaSQLQuoteInfoCollection.GetItem(Index: Integer): TgaSQLQuoteInfoItem;
begin
  Result := TgaSQLQuoteInfoItem(inherited Items[Index]);
end;

function TgaSQLQuoteInfoCollection.Insert(Index: Integer): TgaSQLQuoteInfoItem;
begin
  Result := TgaSQLQuoteInfoItem(inherited Insert(Index));
end;

procedure TgaSQLQuoteInfoCollection.SetItem(Index: Integer; const Value: 
        TgaSQLQuoteInfoItem);
begin
  inherited Items[Index] := Value;
end;


end.
