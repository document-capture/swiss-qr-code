codeunit 88801 "CON QR Code OnRegister"
{
    TableNo = "CDC Document";

    var
        QRCodeHandler: Codeunit "CON QR Code Management";
        PurchaseHeader: Record "Purchase Header";

    trigger OnRun()
    begin
        // check if we can find and read a qr code in the current document
        if QRCodeHandler.ReadSwissPaymentQRCodeInDocument(Rec) then begin
            // Get the created purchase document
            if not PurchaseHeader.GET("Created Doc. Subtype", "Created Doc. No.") then
                exit;

            PurchaseHeader.Validate("Swiss QRBill", true);
            PurchaseHeader.Validate("Swiss QRBill Amount", QRCodeHandler.GetAmt());
            PurchaseHeader.Validate("Swiss QRBill IBAN", QRCodeHandler.GetIBAN());
            PurchaseHeader.Validate("Swiss QRBill Bill Info", QRCodeHandler.GetBillInfo());
            PurchaseHeader.Validate("Swiss QRBill Currency", QRCodeHandler.GetAmtCurrency());
            PurchaseHeader.Validate("Swiss QRBill Unstr. Message", QRCodeHandler.GetUnstructuredMessage());
            PurchaseHeader.Modify(true);
        end;
    end;

}
