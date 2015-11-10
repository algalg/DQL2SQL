unit DQL2SQLLib_TLB;

// ************************************************************************ //
// WARNING
// -------
// The types declared in this file were generated from data read from a
// Type Library. If this type library is explicitly or indirectly (via
// another type library referring to this type library) re-imported, or the
// 'Refresh' command of the Type Library Editor activated while editing the
// Type Library, the contents of this file will be regenerated and all
// manual modifications will be lost.
// ************************************************************************ //

// $Rev: 52393 $
// File generated on 10.11.2015 11:19:07 from Type Library described below.

// ************************************************************************  //
// Type Lib: C:\Projects\dql2sql\dql2sqlLib (1)
// LIBID: {DF28F8DF-9795-4AAF-BF19-D0D1E0F529D8}
// LCID: 0
// Helpfile:
// HelpString:
// DepndLst:
//   (1) v2.0 stdole, (C:\Windows\SysWOW64\stdole2.tlb)
// SYS_KIND: SYS_WIN32
// ************************************************************************ //
{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers.
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
{$ALIGN 4}

interface

uses Winapi.Windows, System.Classes, System.Variants, System.Win.StdVCL, Vcl.Graphics, Vcl.OleServer, Winapi.ActiveX;


// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:
//   Type Libraries     : LIBID_xxxx
//   CoClasses          : CLASS_xxxx
//   DISPInterfaces     : DIID_xxxx
//   Non-DISP interfaces: IID_xxxx
// *********************************************************************//
const
  // TypeLibrary Major and minor versions
  DQL2SQLLibMajorVersion = 1;
  DQL2SQLLibMinorVersion = 0;

  LIBID_DQL2SQLLib: TGUID = '{DF28F8DF-9795-4AAF-BF19-D0D1E0F529D8}';

  IID_IDQLProcessor: TGUID = '{4DE4873E-3E46-4D57-A095-014A15B82EC6}';
  CLASS_DQLProcessor: TGUID = '{B2ACDFAF-45A8-434D-8369-389C9F4AA2DD}';
type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary
// *********************************************************************//
  IDQLProcessor = interface;
  IDQLProcessorDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library
// (NOTE: Here we map each CoClass to its Default Interface)
// *********************************************************************//
  DQLProcessor = IDQLProcessor;


// *********************************************************************//
// Interface: IDQLProcessor
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {4DE4873E-3E46-4D57-A095-014A15B82EC6}
// *********************************************************************//
  IDQLProcessor = interface(IDispatch)
    ['{4DE4873E-3E46-4D57-A095-014A15B82EC6}']
    function ConvertDqlToSql(const SQL: WideString; out TableNames: WideString): WideString; safecall;
  end;

// *********************************************************************//
// DispIntf:  IDQLProcessorDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {4DE4873E-3E46-4D57-A095-014A15B82EC6}
// *********************************************************************//
  IDQLProcessorDisp = dispinterface
    ['{4DE4873E-3E46-4D57-A095-014A15B82EC6}']
    function ConvertDqlToSql(const SQL: WideString; out TableNames: WideString): WideString; dispid 201;
  end;

// *********************************************************************//
// The Class CoDQLProcessor provides a Create and CreateRemote method to
// create instances of the default interface IDQLProcessor exposed by
// the CoClass DQLProcessor. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoDQLProcessor = class
    class function Create: IDQLProcessor;
    class function CreateRemote(const MachineName: string): IDQLProcessor;
  end;

implementation

uses System.Win.ComObj;

class function CoDQLProcessor.Create: IDQLProcessor;
begin
  Result := CreateComObject(CLASS_DQLProcessor) as IDQLProcessor;
end;

class function CoDQLProcessor.CreateRemote(const MachineName: string): IDQLProcessor;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_DQLProcessor) as IDQLProcessor;
end;

end.

