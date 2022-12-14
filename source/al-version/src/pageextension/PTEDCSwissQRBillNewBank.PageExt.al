pageextension 61110 "PTE DC Swiss QR-Bill New Bank" extends "Swiss QR-Bill Create Vend Bank"
{
    internal procedure FromDCSetDetails(VendorBankAccount: Record "Vendor Bank Account")
    begin
        if Rec.Delete() then;
        Rec.TransferFields(VendorBankAccount);
        Rec.Insert();
    end;

    internal procedure FromDCGetDetails(var VendorBankAccount: Record "Vendor Bank Account")
    begin
        VendorBankAccount := Rec;
    end;

}
