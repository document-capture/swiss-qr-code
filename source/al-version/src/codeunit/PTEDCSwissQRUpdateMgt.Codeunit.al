codeunit 61113 "PTE DC SwissQR Update Mgt"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        SwissQRMgt: Codeunit "PTE DC SwissQR Mgt.";
    begin
        SwissQRMgt.InsertQRAmtFieldToMasterTemplates();
    end;
}
