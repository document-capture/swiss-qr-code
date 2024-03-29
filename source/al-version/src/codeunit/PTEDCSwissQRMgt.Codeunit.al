Codeunit 61110 "PTE DC SwissQR Mgt."
{
    TableNo = "CDC Document";

    var
        TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        CaptureMgt: Codeunit "CDC Capture Management";
        ValidQRBillCodeFound: Integer;
        ImportCancelledMsg: Label 'Registration was canceled! Please setup the QR-IBAN bank account for this vendor first.';
        PurchDocVendBankAccountQst: Label 'A vendor bank account with IBAN or QR-IBAN\%1\was not found.\\Do you want to create a new vendor bank account?', Comment = '%1 - IBAN value';


    trigger OnRun()
    begin
        TransferQRBillContentToInvoice(Rec);
    end;

    local procedure TransferQRBillContentToInvoice(var Document: Record "CDC Document"): Boolean
    var
        DocCat: Record "CDC Document Category";
        FieldValue: Record "CDC Document Value";
        TemplateField: Record "CDC Template Field";
        PurchaseHeader: Record "Purchase Header";
        Handled: Boolean;
        VendBankAccountCode: Code[20];
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);

        if ValidQRBillCodeFound = 0 then
            exit(false);

        OnBeForeTransferQRCodeToInvoice(Document, TempSwissQRBillBuffer, Handled);
        if Handled then
            exit(true);

        // get first valid QR code
        //TempSwissQRBillBuffer.Get(0);

        // Get the field value of the DC field Amount incl. VAT
        if not TemplateField.Get(Document."Template No.", TemplateField.Type::Header, 'AMOUNTINCLVAT') then
            exit;

        if CaptureMgt.GetFieldValue(Document, TemplateField, 0, FieldValue) then begin
            // iterate through found qr codes and check if field value of amt. incl. vat is equal to the qr code
            // if not equal, get the 2nd found valid qr code and transfer it's values into invoice
            if TempSwissQRBillBuffer.FindFirst() then
                repeat

                until (TempSwissQRBillBuffer.Next() = 0) or (FieldValue."Value (Decimal)" = TempSwissQRBillBuffer.Amount)
        end;

        // Get the created purchase document
        if not PurchaseHeader.GET(Document."Created Doc. Subtype", Document."Created Doc. No.") then
            exit;

        VendBankAccountCode := GetVendorBankAccount(Document, TempSwissQRBillBuffer);
        PurchaseHeader.VALIDATE("Swiss QR-Bill", TRUE);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Amount", TempSwissQRBillBuffer.Amount);
        PurchaseHeader.VALIDATE("Swiss QR-Bill IBAN", TempSwissQRBillBuffer.IBAN);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Bill Info", TempSwissQRBillBuffer."Billing Information");
        PurchaseHeader.VALIDATE("Swiss QR-Bill Currency", TempSwissQRBillBuffer.Currency);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Unstr. Message", TempSwissQRBillBuffer."Unstructured Message");
        PurchaseHeader.VALIDATE("Payment Reference", TempSwissQRBillBuffer."Payment Reference");
        PurchaseHeader.MODIFY(TRUE);

        SetOPPPaymentBankCode(PurchaseHeader, VendBankAccountCode);
    end;

    local procedure IdentifyVendorFromQRCode(var Document: Record "CDC Document") VendorIdentified: Boolean
    var
        DocCat: Record "CDC Document Category";
        Template: Record "CDC Template";
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
        RecRef: RecordRef;
        TooManyVendorsFound: Boolean;
        SourceID: Integer;
        QRIdentificationTxt: Label 'QR Bill IBAN: %1';
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        // get found qr buffer
        if TempSwissQRBillBuffer.FindFirst() then
            repeat
                VendorBankAccount.SetRange(IBAN, TempSwissQRBillBuffer.IBAN);
                if not VendorBankAccount.IsEmpty then begin
                    if VendorBankAccount.FindSet() then begin
                        Vendor.Get(VendorBankAccount."Vendor No.");
                        repeat
                            TooManyVendorsFound := VendorBankAccount."Vendor No." <> Vendor."No.";
                        until (VendorBankAccount.Next() = 0) or (TooManyVendorsFound);

                        if not TooManyVendorsFound then begin
                            RecRef.GET(Vendor.RecordId);
                            SourceID := RecIDMgt.GetRecIDTreeID(RecRef, TRUE);
                            Commit();

                            Document.Validate("Source Record ID Tree ID", SourceID);
                            Document."Identified by" := COPYSTR(STRSUBSTNO(QRIdentificationTxt, TempSwissQRBillBuffer.IBAN), 1,
                              MaxStrLen(Document."Identified by"));
                            VendorIdentified := Document.Modify(true)
                        end;
                    end;
                end;
            until (TempSwissQRBillBuffer.Next() = 0) or TooManyVendorsFound or VendorIdentified;
    end;


    local procedure SetQRAmountInclVATFromQRCode(var
                                                     Document: Record "CDC Document";

var
Field: Record "CDC Template Field";

var
Word: Text[1024]): Boolean
    var
        DocumentValue: Record "CDC Document Value";
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        if not TempSwissQRBillBuffer.FindLast() then
            exit;

        Word := Format(TempSwissQRBillBuffer.Amount, 0, 2);

        CaptureMgt.UpdateFieldValue(Document."No.", 1, 0, Field, Word, false, false);

        exit(true);
    end;

    local procedure SetVendorBankAccountFromQRCode(var Document: Record "CDC Document"; var Field: Record "CDC Template Field"; var Word: Text[1024]): Boolean
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        if not TempSwissQRBillBuffer.FindLast() then
            exit;

        Word := TempSwissQRBillBuffer.IBAN;

        CaptureMgt.UpdateFieldValue(Document."No.", 1, 0, Field, Word, false, false);
        exit(true);
    end;

    local procedure SetCurrencyFromQRCode(var Document: Record "CDC Document"; var Field: Record "CDC Template Field"; var Word: Text[1024]): Boolean
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);
        if ValidQRBillCodeFound = 0 then
            exit(false);

        if not TempSwissQRBillBuffer.FindLast() then
            exit;

        Word := TempSwissQRBillBuffer.Currency;

        CaptureMgt.UpdateFieldValue(Document."No.", 1, 0, Field, Word, false, false);
        exit(true);
    end;

    local procedure FindQRPaymentCodeInDocument(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer") ValidQRBillCodeFound: integer
    var
        CDCDocumentWord: Record 6085592;
        CurrentSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        //SwissQRBillDecode: Codeunit "PTE DC SwissQR Decode";
        SwissQRBillDecode: Codeunit "Swiss QR-Bill Decode";

        QRBillInStream: InStream;
        CrLf: Text;
        CurrentQRCodeLine: Text;
        QRBillContent: Text;
    begin
        TempSwissQRBillBuffer.DeleteAll();

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
            Clear(CurrentSwissQRBillBuffer);
            Clear(SwissQRBillDecode);
            CDCDocumentWord.CALCFIELDS(Data);
            if CDCDocumentWord.Data.HASVALUE THEN BEGIN
                CDCDocumentWord.Data.CREATEINSTREAM(QRBillInStream);
                while (NOT QRBillInStream.EOS) DO BEGIN
                    QRBillInStream.READTEXT(CurrentQRCodeLine);
                    QRBillContent += CurrentQRCodeLine + CrLf;
                    CLEAR(CurrentQRCodeLine);
                END;
                //if SwissQRBillDecode.DecodeQRCodeText(TempSwissQRBillBuffer, QRBillContent) then
                //ValidQRBillCodeFound += 1;
                if SwissQRBillDecode.DecodeQRCodeText(CurrentSwissQRBillBuffer, QRBillContent) then begin
                    if IsNewQRBillCode(TempSwissQRBillBuffer, CurrentSwissQRBillBuffer) then begin
                        if ValidQRBillCodeFound > 0 then
                            ValidQRBillCodeFound += 1;

                        TempSwissQRBillBuffer.Init();
                        TempSwissQRBillBuffer."Entry No." := ValidQRBillCodeFound;
                        TempSwissQRBillBuffer.Insert();
                        TempSwissQRBillBuffer.TransferFields(CurrentSwissQRBillBuffer, false);
                        TempSwissQRBillBuffer.Modify();
                    end;
                end;
            END;
        until (CDCDocumentWord.Next() = 0);// OR (ValidQRBillCodeFound >= 2);

        exit(TempSwissQRBillBuffer.Count);
    end;

    local procedure ValidateAmountsInclVat(var Document: Record "CDC Document"; var IsInvalid: Boolean)
    var
        DocCat: Record "CDC Document Category";
        DocumentComment: Record "CDC Document Comment";
        TemplateFieldAmount: Record "CDC Template Field";
        TemplateFieldQRAmount: Record "CDC Template Field";
        AmountInclVat: Decimal;
        QRAmountInclVat: Decimal;
        QRAmountDoNotMatchComment: Label 'The value of %1 (%2) is not equal to %3 (%4). Make sure that both values match.';
    begin
        if IsPurchaseInvoiceCategory(Document) then begin
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
    end;

    local procedure IsPurchaseInvoiceCategory(var Document: Record "CDC Document"): Boolean
    var
        DocCat: Record "CDC Document Category";
        IsHandled: Boolean;
        PurchaseInvoiceCategory: Boolean;
    begin
        OnBeforeIsPurchaseInvoiceCategory(Document, PurchaseInvoiceCategory, IsHandled);
        if IsHandled then
            exit(PurchaseInvoiceCategory);

        if not DocCat.Get(Document."Document Category Code") then
            exit;

        if DocCat."Source Table No." <> 23 then
            exit;

        if (DocCat."Destination Header Table No." <> 38) or (DocCat."Destination Line Table No." <> 39) then
            exit;

        exit(true);
    end;

    local procedure GetVendorBankAccount(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer"): Code[20]
    var
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
        VendorBankAccount2: Record "Vendor Bank Account";
        SwissQRBillCreateVendBank: page "Swiss QR-Bill Create Vend Bank";
        VendBankAccountFound: Boolean;
        ErrorOnVendBankAccInsert: Label 'Vendor Bank Account %1 couldn''t be inserted.\IBAN: %2', Locked = true;
    begin
        if not IsPurchaseInvoiceCategory(Document) then
            exit;

        ValidQRBillCodeFound := TempSwissQRBillBuffer.Count;
        if ValidQRBillCodeFound = 0 then
            ValidQRBillCodeFound := FindQRPaymentCodeInDocument(Document, TempSwissQRBillBuffer);

        if ValidQRBillCodeFound = 0 then
            exit;

        // Search for last qr code due to documents, where we have seen two qr codes on documents
        if not TempSwissQRBillBuffer.FindLast() then
            exit;

        if not Vendor.Get(Document."Source Record No.") then
            exit;

        // Check if there is an existing vendor bank account for the QR IBAN 
        VendorBankAccount.SetRange("Vendor No.", Document."Source Record No.");
        VendorBankAccount.SetRange("Payment Form", VendorBankAccount."Payment Form"::"Bank Payment Domestic");
        if VendorBankAccount.FindSet() then
            repeat
                // check if QR IBAN is equal to Vend. bank account without spaces
                if (DelChr(VendorBankAccount.IBAN) = TempSwissQRBillBuffer.IBAN) then
                    exit(VendorBankAccount.Code);
            until (VendorBankAccount.Next() = 0);

        // No vendor bank account found - ask user to create one
        if Confirm(StrSubstNo(PurchDocVendBankAccountQst, TempSwissQRBillBuffer.IBAN)) then begin
            Clear(VendorBankAccount);
            VendorBankAccount."Vendor No." := Document."Source Record No.";
            VendorBankAccount.Code := GetVendorBankAccountCode(Document."Source Record No.", TempSwissQRBillBuffer.IBAN);
            VendorBankAccount.IBAN := TempSwissQRBillBuffer.IBAN;
            VendorBankAccount."Payment Form" := VendorBankAccount."Payment Form"::"Bank Payment Domestic";
            if VendorBankAccount.Insert(true) then
                exit(VendorBankAccount.Code)
            else
                Error(ErrorOnVendBankAccInsert, VendorBankAccount.Code, TempSwissQRBillBuffer.IBAN);
        end else
            Error(ImportCancelledMsg);
    end;

    // Procedure to check if the OPplus field for Payment Bank Code is existing
    // If the field exists we write the QR IBAN Vendor Bank account code into this field
    local procedure SetOPPPaymentBankCode(PurchaseHeader: Record "Purchase Header"; VendBankAccountCode: Code[20])
    var
        RecRef: RecordRef;
        PaymBankCode: FieldRef;
    begin
        if RecRef.Get(PurchaseHeader.RecordId) then
            if RecRef.FieldExist(5157894) then begin
                PaymBankCode := RecRef.Field(5157894);
                PaymBankCode.Validate(VendBankAccountCode);  // use the Bank Code value we have set before
                RecRef.Modify()
            end;
    end;

    local procedure GetVendorBankAccountCode(VendorNo: Code[20]; IBAN: Code[50]) BankCode: Code[20]
    var
        VendorBankAcount: Record "Vendor Bank Account";
        iidAsInteger: Integer;
        DefaultBankCode: Label 'IBAN', Locked = true;
        EvalIbanError: Label 'IBAN IID kann nicht ausgelesen werden!\IBAN: %1', Locked = true;
        IbanBankCode: Label 'QR-IBAN', Locked = true;
    begin
        // check if IBAN is normal IBAN or QR-IBAN
        // QR-IID is between 30000 and 31999 at characters 5-9
        if not Evaluate(iidAsInteger, CopyStr(IBAN, 5, 5)) then
            error(EvalIbanError, IBAN);

        if (iidAsInteger >= 30000) and (iidAsInteger < 31999) then
            BankCode := IbanBankCode
        else
            BankCode := DefaultBankCode;

        VendorBankAcount.SetRange("Vendor No.", VendorNo);
        VendorBankAcount.SetFilter(Code, StrSubstNo('%1*', BankCode));
        if not VendorBankAcount.FindLast() then  // return new bank code
            exit;

        // increment found bank code
        BankCode := IncStr(VendorBankAcount.Code);
        if BankCode = '' then  //IncStr returns empty string if no number in incremented string
            BankCode := VendorBankAcount.Code + '2';
    end;

    local procedure IsNewQRBillCode(TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer"; CurrentSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary): Boolean
    begin
        if (TempSwissQRBillBuffer.IBAN <> CurrentSwissQRBillBuffer.IBAN) or
           (TempSwissQRBillBuffer.Amount <> CurrentSwissQRBillBuffer.Amount) or
           (TempSwissQRBillBuffer."Payment Reference" <> CurrentSwissQRBillBuffer."Payment Reference") or
           (TempSwissQRBillBuffer."Billing Information" <> CurrentSwissQRBillBuffer."Billing Information")
        then
            exit(true);
    end;

    internal procedure InsertQRAmtFieldToMasterTemplates()
    var
        DocCat: Record "CDC Document Category";
        Template: Record "CDC Template";
        AmtInclTemplateField: Record "CDC Template Field";
        QRAmtInclTemplateField: Record "CDC Template Field";
        QRAmtInclFieldName: Label 'QR Amount incl. VAT';
    begin
        DocCat.SetRange("Source Table No.", 23);
        DocCat.SetRange("Destination Header Table No.", 38);
        DocCat.SetRange("Destination Line Table No.", 39);
        if DocCat.IsEmpty then
            exit;

        if DocCat.FindSet() then
            repeat
                Template.SetRange("Category Code", DocCat.Code);
                Template.SetRange("Data Type", Template."Data Type"::PDF);
                Template.SetRange(Type, Template.Type::Master);
                if Template.FindSet() then
                    repeat
                        if AmtInclTemplateField.Get(Template."No.", AmtInclTemplateField.Type::Header, 'AMOUNTINCLVAT') then
                            if not QRAmtInclTemplateField.Get(Template."No.", QRAmtInclTemplateField.Type::Header, 'QRAMOUNTINCLVAT') then begin
                                Clear(QRAmtInclTemplateField);
                                QRAmtInclTemplateField.Validate("Template No.", Template."No.");
                                QRAmtInclTemplateField.Validate(Type, QRAmtInclTemplateField.Type::Header);
                                QRAmtInclTemplateField.Validate(Code, 'QRAMOUNTINCLVAT');
                                QRAmtInclTemplateField.Validate("Field Name", QRAmtInclFieldName);
                                QRAmtInclTemplateField.Validate("Data Type", QRAmtInclTemplateField."Data Type"::Number);
                                QRAmtInclTemplateField.Validate("Search for Value", true);
                                QRAmtInclTemplateField.Validate("Sort Order", AmtInclTemplateField."Sort Order" + 1);
                                QRAmtInclTemplateField.Validate("Insert on new Templates", true);
                                QRAmtInclTemplateField.Insert(true);
                            end;
                    until Template.Next() = 0;
            until DocCat.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnBeforeRegisterDocument', '', true, true)]
    local procedure PurchaseRegisterOnBeforeRegisterDocument(var Document: Record "CDC Document")
    begin
        GetVendorBankAccount(Document, TempSwissQRBillBuffer);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnAfterRegister', '', true, true)]
    local procedure PurchaseRegisterOnAfterRegister(var Document: Record "CDC Document")
    begin
        TransferQRBillContentToInvoice(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeFindDocumentSource', '', true, true)]
    local procedure CaptureEngineOnBeforeFindDocumentSource(var Document: Record "CDC Document"; var IsHandled: Boolean)
    begin
        IsHandled := IdentifyVendorFromQRCode(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeCaptureField2', '', false, false)]
    local procedure CaptureEngineOnBeforeCaptureField2(var Document: Record "CDC Document"; PageNo: Integer; var Field: Record "CDC Template Field"; UpdateFieldCaption: Boolean; var FieldCaption: Record "CDC Template Field Caption"; var Handled: Boolean; var Word: Text[1024])
    begin
        case Field.Code of
            'QRAMOUNTINCLVAT':
                Handled := SetQRAmountInclVATFromQRCode(Document, Field, Word);
            'VENDORBANKACC':
                Handled := SetVendorBankAccountFromQRCode(Document, Field, Word);
            'CURRCODE':
                Handled := SetCurrencyFromQRCode(Document, Field, Word);
            else
                Handled := false;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Validation", 'OnBeforeValidateAmtAccounts', '', false, false)]
    local procedure PurchValidationOnBeforeValidateAmtAccounts(var Document: Record "CDC Document"; var Template: Record "CDC Template"; var IsInvalid: Boolean; var IsHandled: Boolean)
    begin
        ValidateAmountsInclVat(Document, IsInvalid);
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeForeTransferQRCodeToInvoice(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer"; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeforeIsPurchaseInvoiceCategory(var Document: Record "CDC Document"; var PurchaseInvoiceCategory: Boolean; var IsHandled: Boolean)
    begin
    end;
}