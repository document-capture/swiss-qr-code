pageextension 61110 "PTE DC Swiss QR DocCat Card" extends "CDC Document Category Card"
{
    ContextSensitiveHelpPage = 'how-to-setup-and-enable';

    layout
    {
        addafter(Codeunits)
        {
            group(Extensions)
            {
                Caption = 'QR Bill';

                field("Transfer QR Bill data"; Rec."Transfer QR Bill data")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable if you want to automatically process Swiss payment QR codes, if present on registered document.';
                }
                field("Identify Vendor from QR IBAN"; Rec."Identify Vendor from QR IBAN")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable if you want to identify the vendors from the IBAN no, encoded in the Swiss QR Bill code.';
                }
                field("Validate QR Bill amount"; Rec."Validate QR Bill amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable to check if the QR invoice amount is equal to the captured/calculated amount incl. VAT.';
                }
            }
        }
    }
}