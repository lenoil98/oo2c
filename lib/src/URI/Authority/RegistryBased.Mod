(* 	$Id$	 *)
MODULE URI:Authority:RegistryBased;
(*  Implements class for registry-based authority components.
    Copyright (C) 2000, 2003  Michael van Acken

    This module is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public License
    as published by the Free Software Foundation; either version 2 of
    the License, or (at your option) any later version.

    This module is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with OOC. If not, write to the Free Software Foundation,
    59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*)


IMPORT
  CC := CharClass, TextRider, Object, Exception, ADT:StringBuffer,
  URI, URI:CharClass, URI:String;

TYPE
  Authority* = POINTER TO AuthorityDesc;
  AuthorityDesc* = RECORD
  (**Registry-based authority component of an URI.  This is similar to
     @otype{*URI:Authority:Unparsed.Authority}, except for that the given
     authority name must not be empty, and that any escaped characters are
     replaced by their value.  *)
    (URI.AuthorityDesc)
    regName-: STRING;
    (**Holds the authority substring of a URI.  Escaped characters are
       replaced with their character value.  *)
  END;


PROCEDURE Init* (auth: Authority; regName: STRING);
  BEGIN
    auth. regName := regName
  END Init;

PROCEDURE New* (regName: STRING): Authority;
  VAR
    auth: Authority;
  BEGIN
    NEW (auth);
    Init (auth, regName);
    RETURN auth
  END New;

PROCEDURE (auth: Authority) Clone* (): Authority;
  VAR
    copy: Authority;
  BEGIN
    NEW (copy);
    auth. Copy (copy);
    RETURN copy
  END Clone;

PROCEDURE (auth: Authority) Copy* (dest: URI.Authority);
  BEGIN
    (*auth. Copy^ (dest); procedure is abstract in super class *)
    WITH dest: Authority DO
      dest. regName := auth. regName;
    END
  END Copy;

PROCEDURE (auth: Authority) ParseAuthority* (str: Object.CharsLatin1;
                                             offset: URI.Offset)
RAISES Exception.ParseError;
  VAR
    i: URI.Offset;
  BEGIN
    i := 0;
    WHILE CharClass.SkipAuthChar (str^, i) DO END;
    IF (i = 0) THEN
      RAISE(NEW(Exception.ParseError,
                "Registry-based naming authority must not be empty",
                i+offset));
    ELSIF (str[i] # 0X) THEN
      RAISE(NEW(Exception.ParseError,
                "Illegal character in registry-based naming authority",
                i+offset));
    ELSE
      auth.regName := String.Unescape(Object.NewLatin1(str^));
    END
  END ParseAuthority;

PROCEDURE (auth: Authority) WriteXML* (w: TextRider.Writer);
  BEGIN
    w. WriteString (CC.eol+"<authority-registry-based>");
    w. WriteObject (auth. regName);
    w. WriteString ("</authority-registry-based>")
  END WriteXML;

PROCEDURE (auth: Authority) Append* (sb: StringBuffer.StringBuffer);
  BEGIN
    sb.Append ("//");
    String.AppendEscaped(auth. regName, "$,;:@&=+", sb);
  END Append;

END URI:Authority:RegistryBased.
