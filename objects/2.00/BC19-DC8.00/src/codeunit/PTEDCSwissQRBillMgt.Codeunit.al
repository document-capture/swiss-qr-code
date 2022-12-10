Codeunit 61110 "PTE DC Swiss QR-Bill Mgt."
{

    TableNo = "CDC Document";

    trigger OnRun()
    begin
        ProcessQRCodeOnDocument(Rec);
    end;

    local procedure ProcessQRCodeOnDocument(var Document: Record "CDC Document"): Boolean
    var
        CDCDocumentWord: Record 6085592;
        PurchaseHeader: Record "Purchase Header";
        TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer" temporary;
        TemplateField: Record "CDC Template Field";
        FieldValue: Record "CDC Document Value";
        CaptureMgt: codeunit "CDC Capture Management";
        SwissQRBillDecode: Codeunit "PTE DC Swiss QR-Bill Decode";
        QRBillInStream: InStream;
        ValidQRBillCodeFound: Integer;
        CrLf: Text;
        CurrentQRCodeLine: Text;
        QRBillContent: Text;
        Handled: Boolean;
    begin
        CDCDocumentWord.SETRANGE("Document No.", Document."No.");
        CDCDocumentWord.SETRANGE("Barcode Type", 'QRCODE');
        IF CDCDocumentWord.ISEMPTY THEN
            exit(false);  //no QR-Bill code found

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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnAfterRegister', '', true, true)]
    local procedure PurchaseInvoiceOnAfterRegister(var Document: Record "CDC Document")
    begin
        ProcessQRCodeOnDocument(Document);
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeForeProcessQRCodeOnDocument(var Document: Record "CDC Document"; var TempSwissQRBillBuffer: Record "Swiss QR-Bill Buffer"; var Handled: Boolean)
    begin
    end;
}