pageextension 88800 "CON QR-Code CDC Purch. Invoice" extends "CDC Purch. Invoice With Image"
{
    layout
    {
        modify("Payment Reference")
        {
            Editable = "Swiss QRBill";
        }

        addafter("Foreign Trade")
        {
            group("Swiss QR-Bill Tab")
            {
                Caption = 'QR-Bill';
                Visible = "Swiss QRBill";

                field("Swiss QR-Bill IBAN"; "Swiss QRBill IBAN")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IBAN or QR-IBAN account of the QR-Bill vendor.';

                    /*trigger OnDrillDown()
                    var
                        SwissQRBillIncomingDoc: Codeunit "Swiss QRBill Incoming Doc";
                    begin
                        SwissQRBillIncomingDoc.DrillDownVendorIBAN("Swiss QRBill IBAN");
                    end;*/
                }
                field("Swiss QR-Bill Amount"; "Swiss QRBill Amount")
                {
                    ApplicationArea = All;
                    Importance = Promoted;
                    ToolTip = 'Specifies the total amount including VAT of the QR-Bill.';
                }
                field("Swiss QR-Bill Currency"; "Swiss QRBill Currency")
                {
                    ApplicationArea = All;
                    Importance = Promoted;
                    ToolTip = 'Specifies the currency code of the QR-Bill.';
                }
                field("Swiss QR-Bill Unstr. Message"; "Swiss QRBill Unstr. Message")
                {
                    ApplicationArea = All;
                    Importance = Additional;
                    ToolTip = 'Specifies the unstructured message of the QR-Bill.';
                }
                field("Swiss QR-Bill Bill Info"; "Swiss QRBill Bill Info")
                {
                    ApplicationArea = All;
                    Importance = Additional;
                    ToolTip = 'Specifies the billing information of the QR-Bill.';

                    /*trigger OnDrillDown()
                    var
                        SwissQRBillBillingInfo: Codeunit "Swiss QRBill Bill Info";
                    begin
                        SwissQRBillBillingInfo.DrillDownBillingInfo("Swiss QRBill Bill Info");
                    end;*/
                }
            }
        }
    }

    actions
    {
        addlast(processing)
        {

        }
    }
}
