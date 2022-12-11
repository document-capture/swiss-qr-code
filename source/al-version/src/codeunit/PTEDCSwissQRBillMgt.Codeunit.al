Codeunit 61110 "PTE DC Swiss QR-Bill Mgt."
{
    TableNo = "CDC Document";

    trigger OnRun()
    begin
        ProcessQRCodeOnDocument(Rec);
    end;

    local procedure ProcessQRCodeOnDocument(var Document: Record "CDC Document"): Boolean
    var
        FieldValue: Record "CDC Document Value";
        TemplateField: Record "CDC Template Field";
        PurchaseHeader: Record "Purchase Header";
        TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        CaptureMgt: codeunit "CDC Capture Management";
        Handled: Boolean;
        ValidQRBillCodeFound: Integer;
    begin
        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);

        if ValidQRBillCodeFound = 0 then
            exit(false);

        OnBeForeProcessQRCodeOnDocument(Document, TempSwissQRBillBuffer, Handled);
        if Handled then
            exit(true);

        // get first valid QR code
        TempSwissQRBillBuffer.Get(1);

        if (ValidQRBillCodeFound > 1) then begin

            // Get the field value of the DC field Amount incl. VAT
            TemplateField.Get(Document."Template No.", TemplateField.Type::Header, 'AMOUNTINCLVAT');
            if CaptureMgt.GetFieldValue(Document, TemplateField, 0, FieldValue) then begin

                // check if field value of amt. incl. vat is equal to the qr code
                // if not equal, get the 2nd found valid qr code and transfer it's values into invoice
                if FieldValue."Value (Decimal)" <> TempSwissQRBillBuffer.Amount then
                    TempSwissQRBillBuffer.Get(2);
            end;
        end;

        // Get the created purchase document
        if not PurchaseHeader.GET(Document."Created Doc. Subtype", Document."Created Doc. No.") then
            exit;

        PurchaseHeader.VALIDATE("Bank Code", GetVendorBankCode(Document, PurchaseHeader, TempSwissQRBillBuffer));
        PurchaseHeader.VALIDATE("Swiss QR-Bill", TRUE);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Amount", TempSwissQRBillBuffer.Amount);
        PurchaseHeader.VALIDATE("Swiss QR-Bill IBAN", TempSwissQRBillBuffer.IBAN);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Bill Info", TempSwissQRBillBuffer."Billing Information");
        PurchaseHeader.VALIDATE("Swiss QR-Bill Currency", TempSwissQRBillBuffer.Currency);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Unstr. Message", TempSwissQRBillBuffer."Unstructured Message");
        PurchaseHeader.VALIDATE("Payment Reference", TempSwissQRBillBuffer."Payment Reference");
        PurchaseHeader.MODIFY(TRUE);
    end;

    local procedure GetVendorBankCode(Document: Record 6085590; PurchaseHeader: Record "Purchase Header"; var SwissQRBillBuffer: Record "Swiss QR-Bill Buffer"): Code[20];
    var
        VendorBankAccount: Record 288;
        BankDirectory: Record 11500;
        VendBankCode: Code[20];
        VendBankCodeCounter: Integer;
        Clearing: Text;
    begin
        VendorBankAccount.reset();
        VendorBankAccount.setrange("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
        VendorBankAccount.setrange("Payment Form", VendorBankAccount."Payment Form"::"Bank Payment Domestic");
        VendorBankAccount.setrange(IBAN, SwissQRBillBuffer.IBAN);
        if NOT VendorBankAccount.findfirst() then begin
            //If No -> Create vendor bank account: - Fill in QR-IBAN + search SWifT code of QR-IBAN from field 5 (5 digits) in Bank Directory Clearing
            repeat
                VendBankCodeCounter += 1;
                VendBankCode := STRSUBSTNO('QR-%1', VendBankCodeCounter);
            until (NOT VendorBankAccount.GET(PurchaseHeader."Buy-from Vendor No.", VendBankCode) OR (VendBankCodeCounter >= 100));
            if VendBankCodeCounter >= 100 then
                VendBankCode := 'QR-XXX';

            VendorBankAccount.RESET();
            VendorBankAccount.INIT();
            VendorBankAccount.VALIDATE("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
            VendorBankAccount.VALIDATE(Code, VendBankCode);
            VendorBankAccount.INSERT(TRUE);
            VendorBankAccount.VALIDATE("Payment Form", VendorBankAccount."Payment Form"::"Bank Payment Domestic");
            VendorBankAccount.VALIDATE(IBAN, SwissQRBillBuffer.IBAN);
            //SWifT
            Clearing := COPYSTR(SwissQRBillBuffer.IBAN, 5, 5);
            if BankDirectory.GET(Clearing) then begin
                VendorBankAccount.VALIDATE("SWifT Code", BankDirectory."SWifT Address");
            end;
            VendorBankAccount.MODifY(TRUE);
        end;

        exit(VendorBankAccount.Code);
    END;

    local procedure IdentifyVendorFromQRCode(var Document: Record "CDC Document"): Boolean
    var
        Template: Record "CDC Template";
        TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        VendorBankAccount: Record "Vendor Bank Account";
        Vendor: Record Vendor;
        ValidQRBillCodeFound: Integer;
        TooManyVendorsFound: Boolean;
        DocCat: Record "CDC Document Category";
        RecRef: RecordRef;
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
        SourceID: Integer;
        QRIdentificationTxt: Label 'QR Bill IBAN: %1';
    begin
        // TODO Implement a check if source record even found        if Document."Source Record No." 
        DocCat.GET(Document."Document Category Code");
        if DocCat."Source Table No." <> 23 then
            exit(false);

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        // get found qr buffer
        if TempSwissQRBillBuffer.Get(1) then begin
            VendorBankAccount.SetRange(IBAN, TempSwissQRBillBuffer.IBAN);
            if VendorBankAccount.IsEmpty then
                exit(false)
            else
                if VendorBankAccount.FindSet() then begin
                    Vendor.Get(VendorBankAccount."Vendor No.");
                    repeat
                        TooManyVendorsFound := VendorBankAccount."Vendor No." <> Vendor."No.";
                    until (VendorBankAccount.Next() = 0) or (TooManyVendorsFound);

                    if TooManyVendorsFound then
                        exit(false);

                    RecRef.GET(Vendor.RecordId);
                    SourceID := RecIDMgt.GetRecIDTreeID(RecRef, TRUE);
                    Commit();

                    Document.Validate("Source Record ID Tree ID", SourceID);
                    Document."Identified by" := COPYSTR(STRSUBSTNO(QRIdentificationTxt, TempSwissQRBillBuffer.IBAN), 1,
                      MaxStrLen(Document."Identified by"));
                    exit(Document.Modify(true));
                end;
        end
    end;


    local procedure SetQRAmountInclVATFromQRCode(var Document: Record "CDC Document"; var TemplateField: Record "CDC Template Field"; var Word: Text[1024]): Boolean
    var
        TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        DocumentValue: Record "CDC Document Value";
        CaptureMgt: Codeunit "CDC Capture Management";
        ValidQRBillCodeFound: Integer;
    begin
        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        TempSwissQRBillBuffer.Get(ValidQRBillCodeFound);

        Word := Format(Round(TempSwissQRBillBuffer.Amount, 0.01, '='));

        CaptureMgt.UpdateFieldValue(Document."No.", 1, 0, TemplateField, Word, false, false);

        exit(true);
    end;

    local procedure FindQRPaymentCodeInDocument(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer") ValidQRBillCodeFound: integer
    var
        CDCDocumentWord: Record 6085592;
        SwissQRBillDecode: Codeunit "PTE DC Swiss QR-Bill Decode";
        QRBillInStream: InStream;
        CrLf: Text;
        CurrentQRCodeLine: Text;
        QRBillContent: Text;
    begin
        CDCDocumentWord.SETRANGE("Document No.", Document."No.");
        CDCDocumentWord.SETRANGE("Barcode Type", 'QRCODE');
        IF CDCDocumentWord.ISEMPTY THEN
            exit(0);  //no QR-Bill code found

        CrLf[1] := 13;
        CrLf[2] := 10;

        CDCDocumentWord.FINDSET;
        repeat
            Clear(QRBillContent);
            Clear(QRBillInStream);
            CDCDocumentWord.CALCFIELDS(Data);
            if CDCDocumentWord.Data.HASVALUE THEN BEGIN
                CDCDocumentWord.Data.CREATEINSTREAM(QRBillInStream);
                while (NOT QRBillInStream.EOS) DO BEGIN
                    QRBillInStream.READTEXT(CurrentQRCodeLine);
                    QRBillContent += CurrentQRCodeLine + CrLf;
                    CLEAR(CurrentQRCodeLine);
                END;
                if SwissQRBillDecode.DecodeQRCodeText(TempSwissQRBillBuffer, QRBillContent) then
                    ValidQRBillCodeFound += 1;
            END;
        UNTIL (CDCDocumentWord.NEXT = 0) OR (ValidQRBillCodeFound >= 2);
    end;

    local procedure ValidateAmountsInclVat(var Document: Record "CDC Document"; var IsInvalid: Boolean)
    var
        DocumentComment: Record "CDC Document Comment";
        TemplateFieldQRAmount: Record "CDC Template Field";
        TemplateFieldAmount: Record "CDC Template Field";
        CaptureMgt: Codeunit "CDC Capture Management";
        AmountInclVat: Decimal;
        QRAmountInclVat: Decimal;
        QRAmountDoNotMatchComment: Label 'The value of %1 (%2) is not equal to %3 (%4). Make sure that both values match.';
    begin
        AmountInclVat := CaptureMgt.GetDecimal(Document, 0, 'AMOUNTINCLVAT', 0);
        QRAmountInclVat := CaptureMgt.GetDecimal(Document, 0, 'QRAMOUNTINCLVAT', 0);
        if QRAmountInclVat = 0 then
            exit;

        if AmountInclVat <> QRAmountInclVat then begin
            TemplateFieldQRAmount.Get(Document."Template No.", TemplateFieldQRAmount.type::Header, 'QRAMOUNTINCLVAT');
            TemplateFieldAmount.Get(Document."Template No.", TemplateFieldAmount.type::Header, 'AMOUNTINCLVAT');

            DocumentComment.Add(Document, TemplateFieldQRAmount, 0, DocumentComment.Area::Validation, DocumentComment."Comment Type"::Error,
                                  STRSUBSTNO(QRAmountDoNotMatchComment, TemplateFieldAmount."Field Name", AmountInclVat, TemplateFieldQRAmount."Field Name", QRAmountInclVat));
            IsInvalid := true;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnAfterRegister', '', true, true)]
    local procedure PurchaseInvoiceOnAfterRegister(var Document: Record "CDC Document")
    begin
        ProcessQRCodeOnDocument(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeFindDocumentSource', '', true, true)]
    local procedure CaptureEngineOnBeforeFindDocumentSource(var Document: Record "CDC Document"; var IsHandled: Boolean)
    begin
        IsHandled := IdentifyVendorFromQRCode(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeCaptureField2', '', false, false)]
    local procedure CaptureEngineOnBeforeCaptureField2(var Document: Record "CDC Document"; PageNo: Integer; var Field: Record "CDC Template Field"; UpdateFieldCaption: Boolean; var FieldCaption: Record "CDC Template Field Caption"; var Handled: Boolean; var Word: Text[1024])
    begin
        if Field.Code <> 'QRAMOUNTINCLVAT' then
            exit;
        Handled := SetQRAmountInclVATFromQRCode(Document, Field, Word);
    end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeAutoDelegateDocument', '', false, false)]
    // local procedure CaptureEngineOnBeforeAutoDelegateDocument(var Document: Record "CDC Document"; var IsHandled: Boolean)
    // begin
    //     ValidateAmountsInclVat(Document);
    // end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Validation", 'OnBeforeValidateAmtAccounts', '', false, false)]
    local procedure PurchValidationOnBeforeValidateAmtAccounts(var Document: Record "CDC Document"; var Template: Record "CDC Template"; var IsInvalid: Boolean; var IsHandled: Boolean)
    begin
        ValidateAmountsInclVat(Document, IsInvalid);
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeForeProcessQRCodeOnDocument(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer"; var Handled: Boolean)
    begin
    end;
}