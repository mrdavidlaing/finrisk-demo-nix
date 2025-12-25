      *> MT103 SWIFT Message Generator
      *> Written in 1992. DO NOT TOUCH.
      *> This generates SWIFT MT103 format for customer credit transfers
      
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MT103GEN.
       AUTHOR. LEGACY-SYSTEM.
       DATE-WRITTEN. 1992-01-15.
       
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
       
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INPUT-RECORD.
          05 WS-SENDER-ID       PIC X(20).
          05 WS-RECIPIENT-ID    PIC X(20).
          05 WS-AMOUNT          PIC 9(15)V99.
          05 WS-CURRENCY        PIC X(3).
          05 WS-REFERENCE       PIC X(35).
       
       01 WS-MT103-OUTPUT.
          05 WS-BLOCK1          PIC X(25).
          05 WS-BLOCK2          PIC X(25).
          05 WS-BLOCK3          PIC X(25).
          05 WS-BLOCK4          PIC X(25).
          05 WS-BLOCK5          PIC X(25).
       
       01 WS-DATE-TIME.
          05 WS-DATE            PIC 9(6).
          05 WS-TIME            PIC 9(6).
       
       01 WS-AMOUNT-FORMATTED   PIC Z(14)9.99.
       
       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           DISPLAY "{1:F01TRANSFERXUS33AXXX1234567890}"
           DISPLAY "{2:I103TRANSFERXUS33N}"
           DISPLAY "{3:{108:TRANSFERX-REF}}"
           DISPLAY "{4:"
           
           *> Read input from stdin (JSON format will be parsed by wrapper)
           ACCEPT WS-INPUT-RECORD
           
           *> Format amount
           MOVE WS-AMOUNT TO WS-AMOUNT-FORMATTED
           
           *> Generate MT103 fields
           DISPLAY ":20:" WS-REFERENCE
           DISPLAY ":23B:CRED"
           DISPLAY ":32A:" WS-DATE WS-CURRENCY WS-AMOUNT-FORMATTED
           DISPLAY ":50K:/" WS-SENDER-ID
           DISPLAY ":59:/" WS-RECIPIENT-ID
           DISPLAY ":71A:SHA"
           DISPLAY "-}"
           
           STOP RUN.
       
       END PROGRAM MT103GEN.


