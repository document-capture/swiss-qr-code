Codeunit 61110 "DCADV QR Code Management"
{
    var
        CodeContent: array[33] of Text;

    procedure GetAmt() ReturnValue: Decimal
    begin
        if not Evaluate(ReturnValue, ConvertStr(CodeContent[19], '.', GetDecimalSeprator)) then
            Error('Invalid Amount: %1', CodeContent[19]);
    end;

    procedure GetAmtCurrency() ReturnValue: Code[3]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[20])) then
            exit;

        if (StrLen(ReturnValue) > 3) or (StrLen(ReturnValue) < 1) then
            ReturnValue := '';
    end;

    procedure GetBillInfo() ReturnValue: Text[140]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[32])) then
            exit;
    end;

    procedure GetDecimalSeprator() Seperator: Text[1]
    var
        Amount: Decimal;
    begin
        Amount := 1.11;
        Seperator := DelChr(Format(Amount), '=', '1');
    end;

    procedure GetIBAN() ReturnValue: Text[21]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[4])) then
            exit;
    end;

    procedure GetPaymentReference() ReturnValue: Code[27]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[29])) then
            exit;
    end;

    procedure GetUnstructuredMessage() ReturnValue: Text[140]
    begin
        if not Evaluate(ReturnValue, Format(CodeContent[30])) then
            exit;

        if StrLen(ReturnValue) <= MaxStrLen(ReturnValue) then
            ReturnValue := '';
    end;

    procedure GetVersion(CodeContent: Text) ReturnValue: Code[4]
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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnAfterRegister', '', true, true)]
    local procedure PurchaseInvoiceOnAfterRegister(var Document: Record "CDC Document")
    var

        QRCodeHandler: Codeunit "DCADV QR Code Management";
        PurchaseHeader: Record "Purchase Header";
        VendorBank: Record "Vendor Bank Account";
        BankDirectory: Record "Bank Directory";
        DocumentCategory: Record "CDC Document Category";
        QR_IBAN: Text;
        Clearing: Text;
        NewVendBankCode: Code[10];
        VendBankCodeCounter: Integer;
    begin
        if not DocumentCategory.get(Document."Document Category Code") then
            exit;

        // only proceed if the automatic processing is enabled
        if not DocumentCategory."Auto. Swiss QR Code processing" then
            exit;

        // check if we can find and read a qr code in the current document
        if QRCodeHandler.ReadSwissPaymentQRCodeInDocument(Document) then begin
            // Get the created purchase document
            if not PurchaseHeader.GET(Document."Created Doc. Subtype", Document."Created Doc. No.") then
                exit;

            //Vendor bank check if domestic QR bank payment record for current vendor exists
            QR_IBAN := QRCodeHandler.GetIBAN();
            IF STRLEN(QR_IBAN) = 21 THEN BEGIN
                VendorBank.Reset();
                VendorBank.SetRange("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
                VendorBank.SetRange("Payment Form", VendorBank."Payment Form"::"Bank Payment Domestic");
                VendorBank.SetRange(IBAN, QR_IBAN);
                IF VendorBank.FindFirst() THEN begin
                    //If Yes -> validate bank code in invoice
                    PurchaseHeader.Validate("Bank Code", VendorBank.Code);
                end else begin
                    //If No -> Create vendor bank account: - Fill in QR-IBAN + search SWIFT code of QR-IBAN from field 5 (5 digits) in Bank Directory Clearing

                    repeat
                        VendBankCodeCounter += 1;
                        NewVendBankCode := StrSubstNo('QR-%1', VendBankCodeCounter);
                    until (not VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) or (VendBankCodeCounter >= 100));
                    IF VendBankCodeCounter >= 100 then
                        NewVendBankCode := 'QR-XXX';

                    VendorBank.Reset();
                    VendorBank.Init();
                    VendorBank.Validate("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
                    VendorBank.Validate(Code, NewVendBankCode);
                    VendorBank.Insert(TRUE);
                    VendorBank.Validate("Payment Form", VendorBank."Payment Form"::"Bank Payment Domestic");
                    VendorBank.Validate(IBAN, QR_IBAN);
                    //SWIFT
                    Clearing := CopyStr(QR_IBAN, 5, 5);
                    IF BankDirectory.Get(Clearing) THEN begin
                        VendorBank.Validate("SWIFT Code", BankDirectory."SWIFT Address");
                    end;
                    VendorBank.Modify(true);
                    PurchaseHeader.Validate("Bank Code", VendorBank.Code);
                end;
            END;

            PurchaseHeader.Validate("Swiss QR-Bill", true);
            PurchaseHeader.Validate("Swiss QR-Bill Amount", QRCodeHandler.GetAmt());
            PurchaseHeader.Validate("Swiss QR-Bill IBAN", QRCodeHandler.GetIBAN());
            PurchaseHeader.Validate("Swiss QR-Bill Bill Info", QRCodeHandler.GetBillInfo());
            PurchaseHeader.Validate("Swiss QR-Bill Currency", QRCodeHandler.GetAmtCurrency());
            PurchaseHeader.Validate("Swiss QR-Bill Unstr. Message", QRCodeHandler.GetUnstructuredMessage());
            PurchaseHeader.Validate("Payment Reference", QRCodeHandler.GetPaymentReference());
            PurchaseHeader.Modify(true);
        end;
    end;
}

