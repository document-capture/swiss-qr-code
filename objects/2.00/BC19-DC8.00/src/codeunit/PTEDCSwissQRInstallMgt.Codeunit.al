codeunit 61112 "PTE DC Swiss QR Install Mgt"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        InsertQRAmtFieldToMasterTemplates();
    end;

    local procedure InsertQRAmtFieldToMasterTemplates()
    var
        DocCat: Record "CDC Document Category";
        Template: Record "CDC Template";
        AmtInclTemplateField: Record "CDC Template Field"
        QRAmtInclTemplateField: Record "CDC Template Field"
    begin
        DocCat.SetRange("Source Table No.", 23);
        DocCat.SetRange("Destination Header Table No.", 38);
        DocCat.SetRange("Destination Line Table No.", 39);
        if DocCat.IsEmpty then
            exit;

        if DocCat.FindSet() then
            repeat
                Template.SetRange("Category Code", DocCat.Code);
                Template.SetRange("Data Type", Template."Data Type"::PDF);
                Template.SetRange(Type, Template.Type::Master);
                if Template.FindSet() then
                    repeat
                        if TemplateField.Get(Template."No.", TemplateField.Type::Header, 'AMOUNTINCLVAT') then
                    until Template.Next() = 0;
                    until DocCat.Next() = 0;
    end;

    // // event is executed, when a new company is created and initialized
    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", 'OnCompanyInitialize', '', false, false)]
    // local procedure CompanyInitialize()
    // begin

        // end;

}
