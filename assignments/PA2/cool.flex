/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST] = {}; /* to assemble string constants */
char *string_buf_ptr(string_buf);

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
size_t internal_nest_level(0);
%}

%option noyywrap

%option nodefault
%x BLOCK_COMMENT STRING EAT_STRING_TAIL

%%

 /*
  *  Nested comments
  */
"(*" { BEGIN(BLOCK_COMMENT); }
"*)" {
  cool_yylval.error_msg = "Unmatched *)";
  return ERROR;
}
<BLOCK_COMMENT>{
  <<EOF>> {
    BEGIN(0);
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
  }
  "(*" { ++internal_nest_level; }
  "*)" {
    if (internal_nest_level == 0) {
      BEGIN(0);
    } else {
      --internal_nest_level;
    }
  }
  \n { ++curr_lineno; }
  . {}
}

 /*
  *  The multiple-character operators.
  */
"=>" { return DARROW; }
"<-" { return ASSIGN; }
"<=" { return LE; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class) { return CLASS; }
(?i:else) { return ELSE; }
(?i:fi) { return FI; }
(?i:if) { return IF; }
(?i:in) { return IN; }
(?i:inherits) { return INHERITS; }
(?i:let) { return LET; }
(?i:loop) { return LOOP; }
(?i:pool) { return POOL; }
(?i:then) { return THEN; }
(?i:while) { return WHILE; }
(?i:case) { return CASE; }
(?i:esac) { return ESAC; }
(?i:of) { return OF; }
(?i:new) { return NEW; }
(?i:isvoid) { return ISVOID; }
(?i:not) { return NOT; }
t(?i:rue) {
  cool_yylval.boolean = true;
  return BOOL_CONST;
}
f(?i:alse) {
  cool_yylval.boolean = false;
  return BOOL_CONST;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */
\" {
  string_buf_ptr = string_buf;
  BEGIN(STRING);
}
<STRING>{
  <<EOF>> {
    BEGIN(0);
    cool_yylval.error_msg = "EOF in string constant";
    return ERROR;
  }
  \n {
    ++curr_lineno;
    BEGIN(0);
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
  }
  \\\0|\0 {
    BEGIN(EAT_STRING_TAIL);
    cool_yylval.error_msg = "String contains null character";
    return ERROR;
  }
  \" {
    *string_buf_ptr = '\0';
    BEGIN(0);
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return STR_CONST;
  }
  \\(.|\n) {
    switch (yytext[1]) {
     case 'b':
      *string_buf_ptr = '\b';
      break;

     case 't':
      *string_buf_ptr = '\t';
      break;

     case 'n':
      *string_buf_ptr = '\n';
      break;

     case 'f':
      *string_buf_ptr = '\f';
      break;

     case '\n':
      ++curr_lineno;
     default:
      *string_buf_ptr = yytext[1];
    }
    if (++string_buf_ptr >= string_buf + MAX_STR_CONST) {
      BEGIN(EAT_STRING_TAIL);
      cool_yylval.error_msg = "String constant too long";
      return ERROR;
    }
  }
  . {
    *string_buf_ptr = yytext[0];
    if (++string_buf_ptr >= string_buf + MAX_STR_CONST) {
      BEGIN(EAT_STRING_TAIL);
      cool_yylval.error_msg = "String constant too long";
      return ERROR;
    }
  }
}
<EAT_STRING_TAIL>{
  <<EOF>> { BEGIN(0); }
  \n {
    ++curr_lineno;
    BEGIN(0);
  }
  \" { BEGIN(0); }
  \\\n { ++curr_lineno; }
  . {}
}

\; { return ';'; }
\, { return ','; }
\: { return ':'; }
\{ { return '{'; }
\} { return '}'; }
\( { return '('; }
\) { return ')'; }
\@ { return '@'; }
\. { return '.'; }
\+ { return '+'; }
\- { return '-'; }
\* { return '*'; }
\/ { return '/'; }
\~ { return '~'; }
\< { return '<'; }
\= { return '='; }

[0-9]+ {
  cool_yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}
[A-Z][A-Za-z0-9_]* {
  cool_yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}
[a-z][A-Za-z0-9_]* {
  cool_yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}
\n { ++curr_lineno; }
[ \f\r\t\v]|(--.*) {}
. {
  cool_yylval.error_msg = yytext;
  return ERROR;
}
