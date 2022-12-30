permissionset 61110 "PTE DC SwissQR All"
{
    Access = Internal;
    Assignable = true;
    Caption = 'PTE DC Swiss QR All permissions', Locked = true;

    Permissions =
         codeunit "PTE DC SwissQR Decode" = X,
         codeunit "PTE DC SwissQR Install Mgt" = X,
         codeunit "PTE DC SwissQR Mgt." = X,
         codeunit "PTE DC SwissQR Update Mgt" = X;
}