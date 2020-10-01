# Document-Capture-Swiss-QR-Code

## About the solution ##
This Microsoft Dynamics 365 Business Central Extension is a proof of concept how to process the Swiss payment QR Code recognized by OCR with [Continia Document Capture](https://www.continia.com).
The solution searches for a valid QR code in the document (table CDC Document) during registration and transfers it into the fields of the official Microsoft extension "QR-Bill Management for Switzerland".

## Version ##
The version is based on Business Central Version Spring 2019 (14) - Cumulative Update 13 for the Swiss localization

Used Docker Container: mcr.microsoft.com/businesscentral/onprem:14.14.43294.0-ch

## Disclaimer ##
You can use this code as it is, without any warranty or support by me, [Continia Software](https://www.continia.com "Continia Software").
