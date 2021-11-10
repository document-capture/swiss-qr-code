codeunit 61111 "DCADV QR Code OnRegister"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Register", 'OnAfterRegister', '', true, true)]
    local procedure PurchaseInvoiceOnAfterRegister(var Document: Record "CDC Document")
    var

        QRCodeHandler: Codeunit "DCADV QR Code Management";
        PurchaseHeader: Record "Purchase Header";
        VendorBank: Record "Vendor Bank Account";
        BankDirectory: Record "Bank Directory";
        QR_IBAN: Text;
        Clearing: Text;
        NewVendBankCode: Code[10];
        VendBankCodeCounter: Integer;
    begin

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

