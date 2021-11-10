pageextension 61110 "DCADV QR Code DocCat.Card Ext." extends "CDC Document Category Card"
{
    ContextSensitiveHelpPage = 'how-to-enable';

    layout
    {
        addafter(Codeunits)
        {
            group(Extensions)
            {
                field(AutoSwissQrCodeProcessing; Rec."Auto. Swiss QR Code processing")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable if you want to automatically process Swiss payment QR codes, if present on registered document.';

                }
            }

        }
    }
}
