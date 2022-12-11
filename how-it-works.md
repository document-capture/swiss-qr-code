# How it works

### Short description

Once enabled on the DC Document category this app searches for a valid QRCode in the DC Document, tries to read the content and transfers the found data into the "Swiss QR Bill" fields of the official Microsoft ["QR-Bill Management for Switzerland"](https://appsource.microsoft.com/en-us/product/dynamics-365-business-central/pubid.microsoftdynsmb|aid.qrbillmanagementforbc|pappid.98860128-1333-4598-a3da-0590804648b7?tab=overview) extension.

During this process the app tries to check if there is a Vendor bank account record for the IBAN that is included in the QR Code data. If it is missing, the app is automatically creating a new vendor bank account record in the format **QR-X** (X is replaced with a number), assuming that one vendor might send more than one QR IBAN.

### Detailed description

This app subscribes to the AfterRegister event of the Document Capture codeunit "CDC Purch. - Register". The event is raised after the manual or automatic registration of a Document.

1. The first check is, if the automatic processing of QR Codes is [enabled on the Document Category card.](https://github.com/document-capture/swiss-qr-code/wiki/How-to-enable).
2. In the next step the app is searching in the captured Document data for a barcode of type QRCODE.
3. The barcode data are read from functions inside codeunit **DCADV QR Code Management**
4. The IBAN, that is included in the QR Code is search in the list of Vendor bank accounts
   * If it's found, the bank code is validated into the field "Bank code" on the purchase header record
   * If it's not found the app will try to create a new bank account with the code **QR-X** (X is replaced with an incremented integer, assuming the vendor has more than one QR IBAN)
5. Finally the QR content is validated into the desired fields of the Microsoft QR bill app.
