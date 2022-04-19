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
        SwissQRBillBuffer: Record "Swiss QR-Bill Buffer";
        PurchaseHeader: Record "Purchase Header";
        SwissQRBillDecode: Codeunit "PTE DC Swiss QR-Bill Decode";
        QRBillInStream: InStream;
        QRBillContent: Text;
        CurrentQRCodeLine: Text;
        CrLf: Text;
        ValidQRBillCodeFound: Boolean;
    begin
        CDCDocumentWord.SETRANGE("Document No.", Document."No.");
        CDCDocumentWord.SETRANGE("Barcode Type", 'QRCODE');
        IF CDCDocumentWord.ISEMPTY THEN
            exit(false);  //no QR-Bill code found

        CrLf[1] := 13;
        CrLf[2] := 10;

        CDCDocumentWord.FINDSET;
        repeat
            CDCDocumentWord.CALCFIELDS(Data);
            if CDCDocumentWord.Data.HASVALUE THEN BEGIN
                CDCDocumentWord.Data.CREATEINSTREAM(QRBillInStream);
                while (NOT QRBillInStream.EOS) DO BEGIN
                    QRBillInStream.READTEXT(CurrentQRCodeLine);
                    QRBillContent += CurrentQRCodeLine + CrLf;
                    CLEAR(CurrentQRCodeLine);
                END;
                ValidQRBillCodeFound := SwissQRBillDecode.DecodeQRCodeText(SwissQRBillBuffer, QRBillContent);
            END;
        UNTIL (CDCDocumentWord.NEXT = 0) OR (ValidQRBillCodeFound);

        IF NOT ValidQRBillCodeFound THEN
            EXIT(FALSE);

        // Get the created purchase document
        IF NOT PurchaseHeader.GET(Document."Created Doc. Subtype", Document."Created Doc. No.") THEN
            EXIT;

        PurchaseHeader.VALIDATE("Bank Code", GetVendorBankCode(Document, PurchaseHeader, SwissQRBillBuffer));
        PurchaseHeader.VALIDATE("Swiss QR-Bill", TRUE);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Amount", SwissQRBillBuffer.Amount);
        PurchaseHeader.VALIDATE("Swiss QR-Bill IBAN", SwissQRBillBuffer.IBAN);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Bill Info", SwissQRBillBuffer."Billing Information");
        PurchaseHeader.VALIDATE("Swiss QR-Bill Currency", SwissQRBillBuffer.Currency);
        PurchaseHeader.VALIDATE("Swiss QR-Bill Unstr. Message", SwissQRBillBuffer."Unstructured Message");
        PurchaseHeader.VALIDATE("Payment Reference", SwissQRBillBuffer."Payment Reference");
        PurchaseHeader.MODIFY(TRUE);
        COMMIT;
    end;

    local procedure GetVendorBankCode(Document: Record 6085590; PurchaseHeader: Record "Purchase Header"; var SwissQRBillBuffer: Record "Swiss QR-Bill Buffer"): Code[20];
    var
        VendorBankAccount: Record 288;
        BankDirectory: Record 11500;
        VendBankCodeCounter: Integer;
        VendBankCode: Code[20];
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
    local procedure OnBeForeProcessQRCodeOnDocument(var Document: Record "CDC Document"; var Handled: Boolean)
    begin
    end;

}

