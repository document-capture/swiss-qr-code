Codeunit 88800 "CON QRCode Management"
{

    trigger OnRun()
    var
        CDCDocument: Record "CDC Document";
        CodeContent: array[33] of Text;
    begin
        CDCDocument.Get('D000013');
        if ReadSwissPaymentQRCodeInDocument(CDCDocument) then begin
            Message('%1: %2 - %3 - %4', GetAmtCurrency, GetAmt, GetUnstructuredMessage, GetPaymentReference);
        end;

        CDCDocument.Get('D000014');
        if ReadSwissPaymentQRCodeInDocument(CDCDocument) then begin
            Message('%1: %2 - %3 - %4', GetAmtCurrency, GetAmt, GetUnstructuredMessage, GetPaymentReference);
        end;
    end;

    var
        CodeContent: array[33] of Text;

    local procedure GetAmt() ReturnValue: Decimal
    begin
        if not Evaluate(ReturnValue, ConvertStr(CodeContent[19], '.', GetDecimalSeprator)) then
            Error('Invalid Amount: %1', CodeContent[19]);
    end;

    local procedure GetAmtCurrency() ReturnValue: Code[3]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[20])) then
            exit;

        if (StrLen(ReturnValue) > 3) or (StrLen(ReturnValue) < 1) then
            ReturnValue := '';
    end;

    local procedure GetDecimalSeprator() Seperator: Text[1]
    var
        Amount: Decimal;
    begin
        Amount := 1.11;
        Seperator := DelChr(Format(Amount), '=', '1');
    end;

    local procedure GetPaymentReference() ReturnValue: Code[27]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[29])) then
            exit;
    end;

    local procedure GetUnstructuredMessage() ReturnValue: Text[140]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[30])) then
            exit;

        if StrLen(ReturnValue) <= MaxStrLen(ReturnValue) then
            ReturnValue := '';
    end;

    local procedure GetVersion(CodeContent: Text) ReturnValue: Code[4]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[4])) then
            exit;

        if StrLen(ReturnValue) <> MaxStrLen(ReturnValue) then
            ReturnValue := '';
    end;

    procedure ReadSwissPaymentQRCodeInDocument(var Document: Record "CDC Document") ValidCodeFound: Boolean
    var
        CDCDocumentWord: Record "CDC Document Word";
        CodeInStream: InStream;
        CodeLine: Text;
        LineNo: Integer;
    begin
        CDCDocumentWord.SetRange("Document No.", Document."No.");
        CDCDocumentWord.SetRange("Barcode Type", 'QRCODE');
        if CDCDocumentWord.IsEmpty then
            exit(false);

        CDCDocumentWord.FindSet;
        repeat
            Clear(CodeContent);
            LineNo := 1;
            CDCDocumentWord.CalcFields(Data);
            if CDCDocumentWord.Data.Hasvalue then begin
                CDCDocumentWord.Data.CreateInstream(CodeInStream);
                while (not CodeInStream.eos) and (LineNo < 33) do begin
                    CodeInStream.ReadText(CodeContent[LineNo]);
                    LineNo += 1;
                end;

                // Check if code content is correct
                if CodeContent[1] in ['SPC'] then
                    exit(true);
            end;
        until (CDCDocumentWord.Next = 0) or ValidCodeFound
    end;
}

