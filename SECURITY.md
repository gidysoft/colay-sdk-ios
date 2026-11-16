# Security policy

## Supported versions

Security fixes are made to the latest released version.

## Reporting a vulnerability

Please **do not open a public issue** for security vulnerabilities. Send the details to **info@gidysoft.com** with the subject "Security".
We respond within 3 business days and, once a fix is released, credit your report in the release notes if you wish.

## Security properties of the SDK

- The SDK only uses the **publishable** key that starts with `colay_pk_`; this key can send events but cannot read any data.
- All traffic goes over HTTPS.
- No events are sent without user consent (`analytics` / `ads`); without ads consent, advertising IDs and click IDs are not attached.
