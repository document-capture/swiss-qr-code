codeunit 61112 "PTE DC SwissQR Install Mgt"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        SwissQRMgt: Codeunit "PTE DC SwissQR Mgt.";
    begin
        SwissQRMgt.InsertQRAmtFieldToMasterTemplates();
    end;
}
