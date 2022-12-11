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
        AmtInclTemplateField: Record "CDC Template Field";
        QRAmtInclTemplateField: Record "CDC Template Field";
        QRAmtInclFieldName: Label 'QR Amount incl. VAT';
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
                        if AmtInclTemplateField.Get(Template."No.", AmtInclTemplateField.Type::Header, 'AMOUNTINCLVAT') then
                            if not QRAmtInclTemplateField.Get(Template."No.", QRAmtInclTemplateField.Type::Header, 'QRAMOUNTINCLVAT') then begin
                                Clear(QRAmtInclTemplateField);
                                QRAmtInclTemplateField.Validate("Template No.", Template."No.");
                                QRAmtInclTemplateField.Validate(Type, QRAmtInclTemplateField.Type::Header);
                                QRAmtInclTemplateField.Validate(Code, 'QRAMOUNTINCLVAT');
                                QRAmtInclTemplateField.Validate("Field Name", QRAmtInclFieldName);
                                QRAmtInclTemplateField.Validate("Data Type", QRAmtInclTemplateField."Data Type"::Number);
                                QRAmtInclTemplateField.Validate("Search for Value", true);
                                QRAmtInclTemplateField.Validate("Sort Order", AmtInclTemplateField."Sort Order" + 1);
                                QRAmtInclTemplateField.Validate("Insert on new Templates", true);
                                QRAmtInclTemplateField.Insert(true);
                            end;
                    until Template.Next() = 0;
            until DocCat.Next() = 0;
    end;

    // // event is executed, when a new company is created and initialized
    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", 'OnCompanyInitialize', '', false, false)]
    // local procedure CompanyInitialize()
    // begin

    // end;

}
