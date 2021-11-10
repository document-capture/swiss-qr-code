codeunit 61111 "DCADV QR Code OnRegister"
{
    TableNo = "CDC Document";

    var
        QRCodeHandler: Codeunit "DCADV QR Code Management";
        PurchaseHeader: Record 38;
        VendorBank: Record "Vendor Bank Account";
        BankDirectory: Record "Bank Directory";
        QR_IBAN: Text;
        Clearing: Text;
        NewVendBankCode: Code[10];

    trigger OnRun()
    begin
        // check if we can find and read a qr code in the current document
        if QRCodeHandler.ReadSwissPaymentQRCodeInDocument(Rec) then begin
            // Get the created purchase document
            if not PurchaseHeader.GET(Rec."Created Doc. Subtype", Rec."Created Doc. No.") then
                exit;

            //Kreditorenbank prüfen ob QR Bankzahlung Inland für Kreditor vorhanden
            QR_IBAN := QRCodeHandler.GetIBAN();
            IF STRLEN(QR_IBAN) = 21 THEN BEGIN
                VendorBank.Reset();
                VendorBank.SetRange("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
                VendorBank.SetRange("Payment Form", VendorBank."Payment Form"::"Bank Payment Domestic");
                VendorBank.SetRange(IBAN, QR_IBAN);
                IF VendorBank.FindFirst() THEN begin
                    //Falls Ja -> Bankcode in Rechnung validieren
                    PurchaseHeader.Validate("Bank Code", VendorBank.Code);
                end else begin
                    //Falls Nein -> Kreditor Bankkonto anlegen: - QR-IBAN abfüllen + SWIFT Code suchen von QR-IBAN ab Feld 5 (5 Stellen) in Bank Directory Clearing

                    NewVendBankCode := 'QR-1';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-2';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-3';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-4';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-5';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-6';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-7';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-8';
                    IF VendorBank.Get(PurchaseHeader."Buy-from Vendor No.", NewVendBankCode) then
                        NewVendBankCode := 'QR-9';

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

