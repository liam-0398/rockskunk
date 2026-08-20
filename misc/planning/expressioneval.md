## New Expression Evaluator 

ype
    TLocal = record
        name:    String;
        varType: String;
        offset:  Integer;
    end;

    TGlobal = record
        name:     String;
        varType:  String;
        asmLabel: String;
    end;

    TFunction = record
        name:        String;
        returnType:  String;
        isProcedure: Boolean;
        paramType:   array[0..7] of String;
        paramCount:  Integer;
    end;

    TKind = (kNone, kReg, kMem, kData, kLit);
    TValType = (vtNumber, vtFloat, vtString);

    TValue = record
        vKind:     TKind; // What type of info is passed to NASM, register, memory, literals?
        vType:     TValType; // vtNumber, vtFloat, vtString
        vWordPayload:  Int64; // the word
        vFltPayload:  Double; // the float
        vStringPayload:  String; // register names and data labels eg float_69
        vOffset:    Integer; // the actual offset
    end;

## Flow 

- Runs through lexer/parser as usual 
- Split off from parser at the identifier case branch

# What needs to be done
    - Branch on &, syscall, function call, operand or array (see spec sheet for array syntax)
    - Evaluate right side of arguments, chained as long as possible. left to right prceidence 
    - repolve tokens, strip f if needed, pass if labeled, label if not 
    - fold code

# New Functions
    - Recieve Token and write attricutes to record first thing
    - Fold Code
    - Decide what to do with expression
    - OP and non OP Branch
    


- recordToText pulls record and intelligently emits the correct variable for the asm emissions