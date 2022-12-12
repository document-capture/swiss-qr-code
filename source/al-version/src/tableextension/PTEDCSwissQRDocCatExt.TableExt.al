tableextension 61110 "PTE DC Swiss QR Doc. Cat. Ext." extends "CDC Document Category"
{
    fields
    {
        field(61110; "Transfer QR Bill data"; Boolean)
        {
            Caption = 'Transfer QR Bill data';
            DataClassification = CustomerContent;
        }

        field(61111; "Validate QR Bill amount"; Boolean)
        {
            Caption = 'Validate QR Bill amount';
            DataClassification = CustomerContent;
        }

        field(61112; "Identify Vendor from QR IBAN"; Boolean)
        {
            Caption = 'Identify Vendor from QR IBAN';
            DataClassification = CustomerContent;
        }
    }
}