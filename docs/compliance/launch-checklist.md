# Mesto launch compliance checklist

Working review dated **20 September 2026**. This is an implementation and evidence checklist, not a substitute for final advice from a Bulgarian lawyer.

## Public pages now present

- `/pravna-informatsia` — company/operator identity, service boundary, complaints and ADR.
- `/obshti-uslovia` — website and paid digital-report terms.
- `/poveritelnost` — GDPR Articles 13 and 14 notice, including public-source data.
- `/biskvitki` — necessary cookies, session storage, and external browser requests.
- `/iztochnitsi-na-danni` — sources actually used by the product, acquisition method, legal basis, attribution, evidence, and limitations. Internal approval statuses and unused candidates stay in this checklist rather than appearing on the public page.

All pages have Bulgarian and English variants and appear in the footer and sitemap. Company details are configurable through `LEGAL_ENTITY_*` variables. The defaults reflect the supplied company record for КАДИВЕЛ ЕООД, EIK 208282493.

## Do not enable paid launch until these are complete

1. Before enabling paid consumer orders, add a lawyer-reviewed withdrawal/refund notice and statutory model form; have counsel also review the other public pages, checkout wording, and whether the unlocked report is legally classified as digital content, a digital service, or both.
2. Choose the real payment provider; sign its data-processing terms; record the EEA/third-country hosting and transfer mechanism; update the privacy notice with the provider's name.
3. Send the order confirmation, accepted terms version, immediate-performance consent, and withdrawal acknowledgement to the buyer on a durable medium, normally email. The application records the evidence and shows it on success, but a production mailer still needs to be connected to the real payment completion event.
4. Confirm final consumer price wording and current VAT registration status with the accountant. Do not say “VAT included” while the company is not VAT registered.
5. Decide whether the company will participate in the competent KZP general conciliation commission and make the terms match that decision. Do not add the obsolete EU ODR link; the platform ended on 20 July 2025.
6. Serve Google Fonts and MapLibre locally, or document the relevant recipients, contracts/terms, transfer mechanism, and legitimate-interest assessment. Keep OpenFreeMap disclosed for map pages or replace it with a contracted tile provider.
7. Keep `CHECKOUT_ENABLED=false` in production until items 1–6 and the source permissions below are signed off.

## Source permission actions

Use the ready-to-send Bulgarian request texts and evidence procedure in [`source-permission-requests-bg.md`](source-permission-requests-bg.md).

| Source | Current production decision | Action required before activation | Payment/contract expectation |
| --- | --- | --- | --- |
| OpenStreetMap / Overpass | Approved | Retain ODbL notice, visible attribution, query limits, and derivative-database assessment. | No bespoke contract expected; ODbL compliance required. |
| European Commission VIES | Approved, exact EIK only | Keep the query narrow and result labelled as VAT validation, not a company-register extract. | No bespoke contract expected. |
| OpenFreeMap | Active map service | Archive current terms/privacy, retain attribution, and perform processor/transfer assessment. | Check published service policy; contract a provider if availability/support is needed. |
| SofiaPlan JSON API | `review_required`; blocked | Save the exact API/reuse terms and ask SofiaPlan to confirm commercial reuse, local storage, report display, attribution wording, and update limits for the named dataset IDs. | Likely open-data use without payment, but obtain written confirmation. |
| SofiaPlan ArcGIS layers 31 and 33 | `review_required`; blocked | Obtain confirmation that the general reuse permission covers each exact FeatureServer layer, caching, derived intersections, and commercial reports. | Likely no payment if confirmed as open data. |
| NAG public registers | `review_required`; blocked | Ask Sofia Municipality/NAG for written permission or API terms for automated exact-identifier searches, caching, report display, rate limits, and commercial reuse. | Unknown; be prepared for a written agreement or refusal. |
| KAIS parcel/building/object archives | `review_required`; blocked per archive | Ask AGCC to identify the licence and confirm commercial reuse, local processing, derived reports, attribution, refresh frequency, and whether individual-object archives are included in the high-value dataset release. | High-value parcel/building data should ordinarily be free; a separate written confirmation is still needed for the exact archives. |
| KAIS rights archives | `review_required`; blocked per archive | Request a separate answer for each rights workbook. Confirm whether legal-entity rows may be retained and shown, and confirm that natural-person rows remain excluded. | Do not assume the high-value dataset rule covers ownership/right-holder archives. Contract or additional conditions may be required. |
| Commercial Register | `contract_required`; provider disabled | First inspect and archive the exact `data.egov.bg` CC BY 4.0 dataset and confirm it contains the fields and refresh frequency needed. If not, apply to the Registry Agency for the paid whole-database service and sign the agreement before implementing the provider. | Open-data route may be free; complete database route is paid and contractual. |
| Property Register | `restricted`; provider disabled | Do not automate the public portal. Activate only after the Registry Agency confirms a lawful commercial access route or an authorised contracted provider supplies an appropriate API and terms. | No current lawful Mesto automation route has been established. |

For KAIS, approval is recorded separately per district and archive type:

```sh
bin/rails 'cadastre:approve_archive_permission[Студентски,parcels,AGCC-letter-or-licence-reference]'
bin/rails 'cadastre:enable_archive[Студентски,parcels]'
```

`cadastre:enable_district` intentionally fails until every configured archive for that district is approved. Use `enable_archive` when only particular geometry archives are approved; keep rights archives disabled rather than marking them approved.

## GDPR internal records that are not public pages

These are company records/procedures. Create, approve, owner-assign, and date them before launch:

- Article 30 record of processing activities covering visitors, property checks, anonymous journeys, orders, support, public-register data, logs, and source archives.
- Legitimate interests assessments for security/rate limiting, product event measurement, public-register facts, and public Article 14 notice instead of individual notification.
- DPIA screening; complete a full DPIA if large-scale linkage of public property/company data, systematic monitoring, or higher-risk person data remains in scope.
- Processor and subprocessor register, Article 28 DPAs, hosting regions, and international transfer assessments.
- Retention and deletion schedule with executable owners for unpaid analyses, paid reports, order/accounting evidence, logs, product events, source archives, support mail, and backups.
- Data-subject request procedure and request log; include identity verification, public-source correction, restriction, objection, and one-month deadline handling.
- Personal-data breach response plan and breach register, including the 72-hour supervisory-authority assessment.
- Security measures record: access control, secrets, encryption, backups, restore tests, dependency updates, logging, incident response, and staff access review.
- Source permission register containing the actual letter, licence version, contract, fees, expiry/termination, attribution text, retention, redistribution, and rate limit for every source.
- Cookie/external-request inventory and a release check that prevents non-essential scripts from being added without a consent mechanism.
- Consumer complaint/refund register and the durable confirmation template sent after purchase.

## Recurring controls

- Run `bin/rails data_sources:check` before each release and archive the output.
- Run `bin/rails coverage:status`; investigate stale imports, zero-row changes, or permission drift.
- Review source terms and privacy subprocessors at least quarterly and when an endpoint, dataset, vendor, or product purpose changes.
- Re-run the GDPR/DPIA screening before adding document uploads, user accounts, natural-person ownership, marketing analytics, or data resale.
