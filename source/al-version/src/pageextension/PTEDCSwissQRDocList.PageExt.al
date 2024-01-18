pageextension 61110 "PTE DC Swiss QR Doc. List" extends "CDC Document List With Image"
{
    actions
    {
        addlast(Vendor)
        {

            action("Bank Accounts")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Bank Accounts';
                Image = BankAccount;
                Promoted = true;
                PromotedCategory = Category8;
                PromotedIsBig = true;
                ToolTip = 'View or set up the vendor''s bank accounts. You can set up any number of bank accounts for each vendor.';
                Visible = ShowVendorCard;

                trigger OnAction()
                var
                    VendorBankAccount: Record "Vendor Bank Account";
                begin
                    VendorBankAccount.SetRange("Vendor No.", Rec.GetSourceID);
                    PAGE.RUN(PAGE::"Vendor Bank Account List", VendorBankAccount);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        ShowVendorCard := (Rec.GetSourceID() <> '') AND (GetSourceTableNo = DATABASE::Vendor);
    end;

    internal procedure GetSourceTableNo(): Integer
    var
        DocCat: Record "CDC Document Category";
    begin
        IF Rec."Document Category Code" = '' THEN
            EXIT;

        DocCat.GET(Rec."Document Category Code");
        EXIT(DocCat."Source Table No.");
    end;



    var
        ShowVendorCard: Boolean;
}