grammar Calculette;

@members {
   private TablesSymboles tablesSymboles = new TablesSymboles();

   private int _cur_label = 1;
   private String getNewLabel() { return "Label" +(_cur_label++); }
}

// DEBUT
start returns [ String code ]
@init{ $code = new String(); }   // On initialise code, pour ensuite l'utiliser comme accumulateur
@after{ System.out.println($code); }
    : (decl {$code += $decl.code;})*
      //{ $code += "  JUMP Main\n"; }
        NEWLINE*

      /*  (fonction { $code += $fonction.code; })*
        NEWLINE**/

      //  { $code += "LABEL Main\n"; }
        (instruction { $code += $instruction.code; })*

        { $code += "HALT\n"; }
    ;

// INSTRUCTION
instruction returns [ String code ]
    : expression finInstruction
        {$code = $expression.code;}
    | read finInstruction
        { $code = $read.code;}
    | write finInstruction
        { $code = $write.code;}
    | assignation finInstruction
        { $code = $assignation.code;}
    | while_boucle finInstruction
        { $code = $while_boucle.code;}
    | si
        { $code = $si.code; }
    | boucle_for
        {$code = $boucle_for.code;}
    | boucle_repeat
        {$code = $boucle_repeat.code;}
    | bloc finInstruction?
        { $code = $bloc.code;  }
    | finInstruction
        { $code="";}
    ;

//EXPRESSION
expression returns [ String code ]
   :'(' e=expression ')' {$code = $e.code;}
   | a= expression op = ('*'|'/') b= expression
      {
        $code  =  $a.code + $b.code ;
        if($op.text.equals("*")){
          $code += "MUL \n";
        } else{
          $code += "DIV \n";
        }
      }
   | a= expression op = ('-'|'+') b= expression
      {
        $code  =  $a.code + $b.code ;
        if($op.text.equals("-")){
          $code += "SUB \n";
        } else{
          $code += "ADD \n";
        }
      }
   | ENTIER {$code = "PUSHI " + $ENTIER.text + "\n";}
   | '-' ENTIER {
        $code = "PUSHI -" + $ENTIER.text + "\n";
    }
   | IDENTIFIANT '+=' expression
      { AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
        $code = $expression.code;
        $code += "PUSHG " + at.adresse + "\n" + "ADD\nSTOREG " + at.adresse +"\n";
         }
  | IDENTIFIANT {AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
                 $code = "PUSHG " + at.adresse + "\n";}
  ;

// DECLARATION DE VARIABLE
decl returns [ String code ]
  :'var' IDENTIFIANT ':' TYPE  finInstruction
      {
        tablesSymboles.putVar($IDENTIFIANT.text,$TYPE.text);
        $code = "PUSHI 0 \n";
      }
  | 'var' IDENTIFIANT ':' TYPE '=' expression finInstruction
      {
        tablesSymboles.putVar($IDENTIFIANT.text,$TYPE.text);
        AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
        $code = "PUSHI 0 \n" + $expression.code + "STOREG " + at.adresse+"\n";
      }
  ;

//ASSIGNATION
assignation returns [ String code ]
  : IDENTIFIANT '=' expression
      {
        AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
        $code =  $expression.code + "STOREG " + at.adresse+"\n";
      }
  ;

// READ
read returns [ String code]
  : 'read(' + IDENTIFIANT + ')'
      {
        AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
        $code = "READ \nSTOREG " + at.adresse + "\n";
      }
  ;

// WRITE
write returns [ String code]
  : 'write(' + expression + ')'
      {
        $code = $expression.code + "WRITE \nPOP\n" ;
      }
  ;

// WHILE
while_boucle returns [String code]
  : 'while' WS* '(' + condition + ')' + instruction
      {
        int debut_label = _cur_label;
        $code = "LABEL " + getNewLabel() +"\n";
        $code += $condition.code +"JUMPF Label"+_cur_label+"\n" ;
        $code += $instruction.code ;
        $code += "JUMP Label" + debut_label +"\n";
        $code +="LABEL " + getNewLabel() +"\n";
      }
  ;

//BLOC POUR LE WHILE
bloc returns [String code]
  : {$code ="";} '{' NEWLINE*  (instruction  { $code+=$instruction.code + "\n"; })+  '}';

// CONDITION
condition returns [String code]
  : e1 = expression WS* OPERATEUR WS* e2 = expression
      {
        $code = $e1.code + $e2.code ;
        /*switch ($OPERATEUR.text){
          case "<":
            $code += "INF\n";
          case ">":
            $code += "SUP\n";
          case "<=":
            $code += "INFEQ\n";
          case ">=":
            $code += "SUPEQ\n";
          case "==":
            $code += "EQUAL\n";
          case "!=":
            $code += "NEQ\n";

        }*/
        if($OPERATEUR.text.equals("<")){
          $code += "INF\n";
        }
        else if($OPERATEUR.text.equals(">")){
          $code += "SUP\n";
        }
        else if($OPERATEUR.text.equals("<=")){
          $code += "INFEQ\n";
        }
        else if($OPERATEUR.text.equals(">=")){
          $code += "SUPEQ\n";
        }
        else if($OPERATEUR.text.equals("==")){
          $code += "EQUAL\n";
        }
        else if($OPERATEUR.text.equals("!=")){
          $code += "NEQ\n";
        }
      }
  | c1 = condition WS* '&&' WS* c2 = condition
      {
        $code = $c1.code + $c2.code + "MUL\n";
      }
  | c1 = condition WS* '||' WS* c2 = condition
      {
        $code = $c1.code + $c2.code + "ADD\nPUSHI 0\n SUP\n";
      }
  | '!' WS* condition
      {
        $code = $condition.code + "PUSHI 1 \n" + "NEQ" + "\n";
      }
  | 'true'  { $code = "  PUSHI 1\n"; }
  | 'false' { $code = "  PUSHI 0\n"; }
  ;

// IF
si returns [String code]
  : 'if' WS* '(' condition ')' WS* i1 = instruction
        {
          String fin_du_if =  getNewLabel() + "\n";
          String else_label = getNewLabel() + "\n";
          $code = $condition.code +"JUMPF " + else_label ;
          $code += $i1.code + "JUMP " +fin_du_if;
          $code += "LABEL " + else_label;
        }
     ('else' i2 = instruction { $code += $i2.code;} )?
        { $code+= "LABEL "+ fin_du_if; }
    ;

boucle_for returns [String code]
  : 'for' '(' a1=assignation ';' condition ';' a2=assignation ')' instruction
    {
      int debut_for = _cur_label;
      $code = $a1.code + "LABEL " + getNewLabel() +"\n";
      $code += $condition.code +"JUMPF Label"+_cur_label+"\n" ;
      $code += $instruction.code ;
      $code += $a2.code+"JUMP Label" + debut_for +"\n";
      $code +="LABEL " + getNewLabel() +"\n";
    }
  ;

boucle_repeat returns [String code]
  : 'repeat' instruction 'until' '(' condition ')'
    {
      int debut_repeat = _cur_label;
      $code = "LABEL " + getNewLabel() + "\n";
      $code += $instruction.code;
      $code += $condition.code + " JUMPF Label" + debut_repeat + "\n";
    }
  ;


//FIN D'INSTRUCTION
finInstruction : ( NEWLINE | ';' )+ ;

// lexer

TYPE : 'int' | 'double' ;

OPERATEUR : '<' | '>' |'<=' | '>=' | '==' | '!=' ;

NEWLINE : '\r'? '\n'  ;

COMMENTAIREMONO:(('%') ~('\n')+) ->skip;

COMMENTAIREMULTI:('/*') .*? ('*/')-> skip ;

IDENTIFIANT : (('a'..'z' | 'A'..'Z')+ (('0'..'9') | ('a'..'z' | 'A'..'Z') | '_' )*);

WS :   (' '|'\t')+ -> skip  ;

ENTIER :   ('0'..'9')+   ;

UNMATCH : . -> skip ;
