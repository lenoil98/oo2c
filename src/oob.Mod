(* 	$Id$	 *)
MODULE oob;
(*  Symbol file browser.
    Copyright (C) 2002-2005  Michael van Acken

    This file is part of OOC.

    OOC is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.  

    OOC is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
    License for more details. 

    You should have received a copy of the GNU General Public License
    along with OOC. If not, write to the Free Software Foundation, 59
    Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*)

IMPORT
  Ascii, Err, Out, Strings, Object, IO, IO:StdChannels, OOC:Config:CCompiler,
  CfgData := Config, Config:Section:Options,
  OOC:Config, E := OOC:Error, Rep := OOC:Repository, Sym := OOC:SymbolTable,
  OOC:Logger, OOC:Doc, OOC:Doc:Output:Text, OOC:SymbolTable:ImportModules,
  OOC:SymbolTable:Namespace, OOC:SymbolTable:CreateNamespace,
  OOC:SymbolTable:Builder,
  <*WITH Warnings:=FALSE DO*>Object:Boxed, Object:BigInt;<*END*>


VAR
  cfgErrList, errList: E.List;
  help, extendRecords: Options.Option;
  arg: STRING;
  symTab: Sym.Module;
  noDeclDoc: Sym.Declaration;
  
CONST
  indentString = "  ";
  indentWidth = 2;
  screenWidth = 76;
  
PROCEDURE GetModule (moduleName: STRING): Rep.Module;
  VAR
    m: Rep.Module;
    chars: Object.CharsLatin1;
    str: Object.String8;
  BEGIN
    str := moduleName.ToString8("?");
    chars := str.CharsLatin1();
    m := Config.repositories.GetModule(chars^);
    IF (m = NIL) THEN
      Err.String ("Error: Cannot locate module ");
      Err.Object (moduleName);
      Err.Ln;
      HALT (1)
    END;
    RETURN m;
  END GetModule;

PROCEDURE GetSymTab(module: Rep.Module): Sym.Module
RAISES IO.Error;
  BEGIN
    RETURN module.ReadSymbolFile();
  END GetSymTab;

PROCEDURE WriteSymTab(symTab: Sym.Module);
  CONST
    noSection = -1;
    import = 0;
    constDecl = 1;
    typeDecl = 2;
    varDecl = 3;
    procDecl = 4;
  VAR
    indent: LONGINT;
    currentSection: SHORTINT;
    firstImport: BOOLEAN;
    item: Sym.Item;
    declDoc: Sym.Declaration;
    
  PROCEDURE Newline();
    VAR
      i: LONGINT;
    BEGIN
      Out.Ln;
      FOR i := 1 TO indent DO
        Out.String(indentString);
      END;
    END Newline;

  PROCEDURE SetSection(newSection: SHORTINT);
    BEGIN
      IF (newSection # currentSection) THEN
        IF (currentSection = import) THEN
          Out.String(";");
        END;
        IF (currentSection # noSection) THEN
          DEC(indent);
        END;
        IF (newSection # procDecl) THEN
          Newline;
        END;
        Newline;
        CASE newSection OF
        | import   : Out.String("IMPORT");
        | constDecl: Out.String("CONST");
        | typeDecl : Out.String("TYPE");
        | varDecl  : Out.String("VAR");
        | procDecl : (* nothing *)
        END;
        IF (newSection # procDecl) THEN
          INC(indent);
        END;
        currentSection := newSection;
        Newline;
      ELSIF (currentSection # import) THEN
        Newline;
      END;
    END SetSection;

  PROCEDURE IdentDef(decl: Sym.Declaration);
    BEGIN
      Out.String(decl.name.str^);
      CASE decl.exportMark OF
      | Sym.nameNotExported:
      | Sym.nameExported   : Out.String("*");
      | Sym.nameExportedRO : Out.String("-");
      END;
    END IdentDef;

  PROCEDURE WriteDoc(decl: Sym.Declaration);
    VAR
      indentLevel, i, j: LONGINT;
      str: Doc.String;
    BEGIN
      IF (decl.docString # NIL) THEN
        indentLevel := indent*indentWidth+3;
        str := Text.Convert(decl.docString, indentLevel, screenWidth, 0);

        (* strip whitespace from end of string *)
        i := 0; j := 0;
        WHILE (str[i] # 0X) DO
          IF (str[i] > " ") THEN
            j := i;
          END;
          INC(i);
        END;
        str[j+1] := 0X;
        Strings.Delete(str^, 0, SHORT(indentLevel));
        
        Newline;
        Out.String("(* ");
        Out.String(str^);
        Out.String(" *)");
      END;
    END WriteDoc;

  PROCEDURE ^ VarDecl(varDecl: Sym.VarDecl);
  PROCEDURE ^ ProcDecl(procDecl: Sym.ProcDecl);
  PROCEDURE ^ Type(type, srcCodeType: Sym.Type; VAR declDoc: Sym.Declaration);

  PROCEDURE FormalPars(type: Sym.FormalPars);
    VAR
      i: LONGINT;
    BEGIN
      Out.String("(");
      FOR i := 0 TO LEN(type.params^)-1 DO
        IF (i # 0) THEN
          Out.String("; ");
        END;
        VarDecl(type.params[i]);
      END;
      IF type.anyRestParameters THEN
        Out.String("; ...");
      END;
      Out.String(")");
      IF (type.resultType # NIL) THEN
        Out.String(": ");
        Type(type.resultType, type.srcCodeResultType, noDeclDoc);
      END;
      FOR i := 0 TO LEN(type.raises^)-1 DO
        IF (i = 0) THEN
          Out.String(" RAISES ");
        ELSE
          Out.String(", ");
        END;
        Type(type.raises[i].type, type.raises[i].srcCodeType, noDeclDoc);
      END;
    END FormalPars;
  
  PROCEDURE Type(type, srcCodeType: Sym.Type; VAR declDoc: Sym.Declaration);
  (* If @oparam{declDoc} is not @code{NIL} and there is a suitable place
     to put the documentation, then write it and set the parameter to
     @code{NIL}.  *)
    VAR
      i: LONGINT;
      name: Sym.NameString;
      procDecl: Sym.ProcDecl;
      
    PROCEDURE FieldDecl(fieldDecl: Sym.FieldDecl);
      BEGIN
        Newline;
        IdentDef(fieldDecl);
        Out.String (": ");
        Type(fieldDecl.type, fieldDecl.srcCodeType, noDeclDoc);
        Out.String(";");
      END FieldDecl;

    PROCEDURE RecFields(record: Sym.Record);
    (* Write inherited and local fields.  *)
      VAR
        item: Sym.Item;
      BEGIN
        IF extendRecords.value(CfgData.BooleanVar).boolean &
           (record.baseType # NIL) THEN
          RecFields(record.baseType(Sym.Record));
        END;
        
        item := record.nestedItems;
        WHILE (item # NIL) DO
          WITH item: Sym.FieldDecl DO
            IF (item.exportMark # Sym.nameNotExported) THEN
              FieldDecl(item);
              WriteDoc(item);
            END;
          ELSE  (* ignore *)
          END;
          item := item.nextNested;
        END;
      END RecFields;

    PROCEDURE ModuleName(srcCodeType: Sym.TypeName): Sym.NameString;
      VAR
        currModule: Sym.Module;
        item: Sym.Item;
      BEGIN
        currModule := srcCodeType.Module();
        item := currModule.nestedItems;
        WHILE (item # NIL) DO
          WITH item: Sym.Import DO
            IF (item.name.str^ = srcCodeType.module.str^) THEN
              RETURN item.moduleName.str;
            END;
          ELSE  (* skip *)
          END;
          item := item.nextNested;
        END;
        RETURN NIL;                      (* should not happen *)
      END ModuleName;
    
    BEGIN
      WITH srcCodeType: Sym.TypeName DO
        IF (srcCodeType.module # NIL) & ~srcCodeType.IsPredefReference() THEN
          (* expand the locally used module alias to the full module name;
             this way, aliases make no appearance at all in the output *)
          name := ModuleName(srcCodeType);
          Out.String(name^);
          Out.String(".");
        END;
        Out.String(srcCodeType.ident.str^);

      | type: Sym.Pointer DO
        Out.String("POINTER TO ");
        Type(type.baseType, type.srcCodeBaseType, noDeclDoc);
        
      | type: Sym.FormalPars DO
        Out.String("PROCEDURE");
        FormalPars(type);
        
      | type: Sym.Array DO
        IF type.isOpenArray THEN
          Out.String("ARRAY OF ");
        ELSE
          Out.String("ARRAY ");
          Out.LongInt(type.length, 0);
          Out.String(" OF ");
        END;
        Type(type.elementType, type.srcCodeElementType, noDeclDoc);

      | type: Sym.Record DO
        Out.String("RECORD");
        INC(indent);
        
        IF (type.baseType # NIL) THEN
          Out.String(" (");
          Type(type.baseType, type.srcCodeBaseType, noDeclDoc);
          Out.String(")");
        END;
        IF (declDoc # NIL) THEN
          WriteDoc(declDoc);
          declDoc := NIL;
        END;
        RecFields(type);

        i := 0;
        IF ~extendRecords.value(CfgData.BooleanVar).boolean &
           (type.baseType # NIL) THEN
          i := type.baseType(Sym.Record).tbProcCount;
        END;
        WHILE (i # type.tbProcCount) DO
          procDecl := type.ns(Namespace.Extended).GetTBProcByIndex(i);
          Newline;
          ProcDecl(procDecl);
          Out.String(";");
          WriteDoc(procDecl);
          INC(i);
        END;
        
        DEC(indent);
        Newline;
        Out.String("END");

      | type: Sym.QualType DO
        Type(type.baseType, type.srcCodeBaseType, noDeclDoc);
        Out.String("(");
        FOR i := 0 TO LEN(type.arguments^)-1 DO
          IF (i # 0) THEN
            Out.String(", ");
          END;
          Type(type.arguments[i].type, type.arguments[i].srcCodeType, noDeclDoc);
        END;
        Out.String(")");
      END;
    END Type;

  PROCEDURE Import(import: Sym.Import);
    BEGIN
      IF ~firstImport THEN
        Out.String(", ");
      END;
      firstImport := FALSE;
      Out.String(import.moduleName.str^);
    END Import;
  
  PROCEDURE ConstDecl(constDecl: Sym.ConstDecl);
    PROCEDURE Unprintable(str: STRING): BOOLEAN;
      VAR
        ch: UCS4CHAR;
      BEGIN
        IF (str.length = 1) THEN
          ch := str.CharAt(0);
          RETURN (ch < " ") OR (ch = Ascii.del) OR (ch > MAX(CHAR));
        ELSE
          RETURN FALSE;
        END;
      END Unprintable;
    
    PROCEDURE EscapeChar(ch: UCS4CHAR): STRING;
      VAR
        i: BigInt.BigInt;
      BEGIN
        i := BigInt.NewInt(ORD(ch));
        RETURN "0"+i.Format(16)+"X";
      END EscapeChar;
    
    BEGIN
      IdentDef(constDecl);
      Out.String (" = ");
      IF (constDecl.value = NIL) THEN
        Out.String("NIL");
      ELSIF (constDecl.value IS Boxed.String) &
            Unprintable(constDecl.value(Boxed.String).value) THEN
        Out.Object(EscapeChar(constDecl.value(Boxed.String).value.CharAt(0)));
      ELSE
        Out.Object(constDecl.value);
      END;
    END ConstDecl;
  
  PROCEDURE TypeDecl(typeDecl: Sym.TypeDecl);
    VAR
      ptr: Sym.Item;
      first: BOOLEAN;
    BEGIN
      IdentDef(typeDecl);
      IF (typeDecl.type IS Sym.TypeVar) THEN
        Out.String(": ");
        Type(typeDecl.type(Sym.TypeVar).bound,
             typeDecl.type(Sym.TypeVar).srcCodeBound, declDoc);
      ELSE
        IF typeDecl.HasTypeParameters() THEN
          Out.String("(");
          first := TRUE;
          ptr := typeDecl.type.parent(Sym.TypePars).nestedItems;
          WHILE (ptr # NIL) DO
            WITH ptr: Sym.TypeDecl DO
              IF first THEN
                first := FALSE;
              ELSE
                Out.String("; ");
              END;
              TypeDecl(ptr);
            ELSE
              (* ignore *)
            END;
            ptr := ptr.nextNested;
          END;
          Out.String(")");
        END;
        
        Out.String (" = ");
        Type(typeDecl.type, typeDecl.srcCodeType, declDoc);
      END;
    END TypeDecl;

  PROCEDURE VarDecl(varDecl: Sym.VarDecl);
    BEGIN
      IF varDecl.isVarParam THEN
        Out.String("VAR ");
      END;
      IdentDef(varDecl);
      Out.String (": ");
      Type(varDecl.type, varDecl.srcCodeType, noDeclDoc);
    END VarDecl;
  
  PROCEDURE ProcDecl(procDecl: Sym.ProcDecl);
    BEGIN
      Newline;
      Out.String("PROCEDURE ");
      IF procDecl.IsTypeBound() THEN
        Out.String("(");
        VarDecl(procDecl.formalPars.receiver);
        Out.String(") ");
      END;
      IdentDef(procDecl);
      FormalPars(procDecl.formalPars);
    END ProcDecl;

  PROCEDURE WriteTopLevel(item: Sym.Item): BOOLEAN;
    BEGIN
      (* non-declarations are skipped on the top level, and type-bound
         procedures are written as part of their records *)
      RETURN (item IS Sym.Declaration) &
          (~(item IS Sym.ProcDecl) OR ~item(Sym.ProcDecl).IsTypeBound());
    END WriteTopLevel;
  
  BEGIN
    indent := 0;
    currentSection := noSection;
    firstImport := TRUE;
    Out.String("MODULE "); Out.String(symTab.name.str^); Out.String(";");

    item := symTab.nestedItems;
    WHILE (item # NIL) DO
      IF WriteTopLevel(item) THEN
        declDoc := item(Sym.Declaration);
        WITH item: Sym.Import DO
          IF (item.name.str[0] # Builder.prefixAutoImport) THEN
            SetSection(import);
            Import(item);
          END;
          declDoc := NIL;
        | item: Sym.ConstDecl DO
          SetSection(constDecl);
          ConstDecl(item);
        | item: Sym.TypeDecl DO
          SetSection(typeDecl);
          TypeDecl(item);
        | item: Sym.VarDecl DO
          SetSection(varDecl);
          VarDecl(item);
        | item: Sym.ProcDecl DO
          SetSection(procDecl);
          ProcDecl(item);
        END;
        IF ~(item IS Sym.Import) THEN
          Out.String(";");
        END;
        IF (declDoc # NIL) THEN
          WriteDoc(declDoc)
        END;
      END;
      item := item.nextNested;
    END;

    IF (currentSection # noSection) & (currentSection # procDecl) THEN
      DEC(indent);
    END;
    Newline;
    Newline;
    Out.String("END "); Out.String(symTab.name.str^); Out.String(".");
    Newline;
  END WriteSymTab;

PROCEDURE WriteHelp;
  BEGIN
    Out.String ("Usage: oob [options] <module>"); Out.Ln;
    Out.String ("Options:"); Out.Ln;
    Out.String ("--config <file>           Use <file> as primary configuration file."); Out.Ln;
    Out.String ("--repository <directory>  Add repository."); Out.Ln;
    Out.String ("-r <directory>            Add repository."); Out.Ln;
    Out.String ("--extended, -x            Include inherited members in records."); Out.Ln;
    Out.String ("--help, -h                Write this text and exit."); Out.Ln;
  END WriteHelp;

PROCEDURE NewConfig;
  BEGIN
    Config.AddRepositoryListEnv();
    Config.AddCmdLine("--repository,-r",
                 "<repositories><file-system>$1</file-system></repositories>");
    
    help := Config.AddOption("help", CfgData.NewBooleanVar(FALSE));
    Config.AddCmdLine("-h,--help",
                      "<options><set name='help'>TRUE</set></options>");

    extendRecords := Config.AddOption("extendRecords", CfgData.NewBooleanVar(FALSE));
    Config.AddCmdLine("-x,--extended",
                      "<options><set name='extendRecords'>TRUE</set></options>");

    CCompiler.RegisterConfig;  (* make oo2c options known *)
  END NewConfig;

BEGIN
  noDeclDoc := NIL;
  Logger.silence := TRUE;
  cfgErrList := E.NewList("");
  NewConfig;
  Config.Read(cfgErrList);
  
  IF (cfgErrList. msgCount # 0) THEN
    cfgErrList. Write (StdChannels.stderr);
  END;
  IF ~cfgErrList.NoErrors() THEN
    HALT (1)
  ELSIF (Config.arguments.ArgNumber() # 1) THEN
    WriteHelp;
    HALT(1);
  ELSIF help.value(CfgData.BooleanVar).boolean THEN
    WriteHelp
  ELSE
    Rep.readDocStrings := TRUE;
    arg := Config.arguments.Get(0);
    symTab := GetSymTab(GetModule(arg));
    errList := E.NewList("");
    ImportModules.ImportModules(CreateNamespace.systemModule, symTab, errList);
    IF errList.NoErrors() THEN
      CreateNamespace.CreateNamespace(symTab, NIL, errList);
      IF errList.NoErrors() THEN
        WriteSymTab(symTab);
      END;
    END;
  END
END oob.
