# Public registry intelligence and the Mesto Property Graph

Research verified on **20 September 2026**. This note records the product and implementation boundary; it is not legal advice.

## Source decisions

| Source | Official access found | Mesto automation decision | Main limitation |
| --- | --- | --- | --- |
| Registry Agency — Property Register | Paid authenticated remote references exist. The published automated interface is for public institutions with an express statutory basis and uses an approved client certificate. | `PropertyRegistry::UnavailableProvider` is the production default. No portal account, QES, payment flow, credential, or session is automated. | Mesto cannot currently establish registered ownership or ownership history programmatically. A future contractually authorized provider can implement the transport-neutral `PropertyRegistry::ContractProvider` boundary. |
| Registry Agency — Commercial Register / NPLE Register | The Registry Agency offers the complete database/structured parts as a paid contractual service. Separately, registri.bg's public terms identify a `data.egov.bg` Commercial Register route under CC BY 4.0; the exact dataset, fields, freshness, and licence record still need to be independently archived and verified for Mesto. | `CommercialRegistry::UnavailableProvider` is the default. Before implementation, choose either the verified open-data dataset or the paid Registry Agency feed and record the applicable terms. The public portal is not scraped. | The open-data and paid-feed routes have different scope and conditions. The paid feed is contract-dependent and its published terms restrict onward provision. |
| AGCC / KAIS cadastre | AGCC publishes six applicable district archives: three object/geometry archives and three XLSX rights snapshots (`собственост ПИ`, `собственост сгради`, `собственост СОС`). | Import exact company and public/legal-organization right rows for cadastral objects inside prepared coverage. A valid EIK creates a company node. Masked natural-person rows are omitted before persistence. | A cadastral-register rights snapshot is not a current Property Register reference and cannot establish complete title history or encumbrances. Bulk ingestion remains `review_required` and is blocked in production until permission/reuse review is approved. |
| European Commission VIES | Public SOAP validation by country code and VAT number. | Check only exact property-related EIKs. Retain the dated validity result and returned company name; discard the returned address. | VIES establishes only VAT-number validity at the check date, not company status, management, ownership, or property rights. |
| Sofia NAG public registers | Public registers expose searchable/exportable administrative records and redacted public documents. | Reuse the prepared NAG database only. An edge to an act requires a cadastral identifier found in the published document (`match_basis=document`). A company mention is retained only when the same public record contains an exact checksum-valid EIK; raw applicant/person fields remain removed. | A permit, visa, applicant, contracting authority, address, or project role does not establish property ownership or authority to sell. Background ingestion remains disabled by default and `review_required`. |
| SofiaPlan | SofiaPlan publishes an official JSON open-data API, which Mesto already prepares into spatial datasets. | Reuse prepared datasets. A planning/development edge requires an actual parcel/feature geometry intersection and records the dataset revision and relevant date. | Dataset age and geographic coverage vary. A spatial intersection is not ownership and does not by itself authorize a specific development. Permission metadata remains explicit in `config/data_sources.yml`. |

Official references:

- [Property Register automated access for official purposes](https://www.registryagency.bg/bg/registri/imoten-registar/avtomatiziran-dostp-do-bazata-danni-na-imoten-registr-za-sluzheb/)
- [Property Register remote property-reference help](https://portal.registryagency.bg/help/topics/pr-applicationprocesses-requestforreportforproperty.html)
- [Property Register special access](https://www.registryagency.bg/bg/registri/imoten-registar/specialen-dostp/)
- [Commercial Register complete database and automated services](https://www.registryagency.bg/bg/registri/targovski-registar/predostavyane-sreshtu-zaplashtane-na-cyalata-baza-danni/)
- [Commercial Register automated-access general terms](https://www.registryagency.bg/media/filer_public/2021/08/27/obshchi_usloviia_updated_26082021.pdf)
- [KAIS open-data page](https://kais.cadastre.bg/bg/OpenData)
- [KAIS remote-service terms](https://kais.cadastre.bg/bg/Terms)
- [KAIS WMS service requirements](https://kais.cadastre.bg/bg/Services/Info?applicationType=fc5c1281-a795-4cd1-9c2f-75e792923cd0&id=4da5081c-1c86-4233-9fa5-0237a2afad13)
- [Sofia NAG register catalogue](https://nag.sofia.bg/pages/render/187)
- [SofiaPlan open-data API documentation](https://sofiaplan.bg/api/)

## PostgreSQL domain model

`property_graph_entities` deduplicates an entity by a non-ambiguous canonical key:

- cadastral objects: exact cadastral identifier;
- companies: exact checksum-valid EIK;
- administrative/planning records: source namespace plus stable source record key;
- people: a non-sensitive stable provider key, or a deliberately source-scoped digest. Names alone never merge people across records.

`property_graph_entity_observations` stores per-dossier, source-specific facts. A later observation does not delete an earlier one. Personal numbers, birth dates, contact details, and personal addresses are removed before persistence.

`property_graph_relationships` stores subject/object, type, exact source record and URL, source date, first/last observation, validity dates, active/superseded state, subject/object scope, evidence, confidence status, origin, and coverage limitation. Refreshes close missing current edges without deleting them.

`claim_origin` already separates `public_source` from the reserved `uploaded_document` origin. No document-derived relationship is produced in this change.

## Supported relationship rules

- `part_of_building`: exact imported individual-object and building records.
- `building_on_parcel`: exact imported building and parcel records.
- `cadastre_right_holder`: exact company/public-organization row from an AGCC rights workbook, retaining the right and document descriptions. It is never presented as a Property Register title check.
- `related_administrative_act`: cadastral identifier explicitly present in a published NAG document.
- `named_in_administrative_act`: public company name and valid EIK explicitly present in that act; never an ownership claim.
- `related_development` / `related_planning_record`: actual parcel intersection with a prepared spatial feature.
- `managed_by`, `owned_by`, `beneficially_owned_by`: normalized only from an approved company-registry payload, with current and historical validity retained.
- `registered_owner` / `previous_registered_owner`: normalized only from an approved Property Register payload. These paths are implemented and tested but cannot run with the current unavailable provider.

VIES contributes a dated company observation, not a graph edge.

`unresolved` edges may be retained internally but are excluded from the user-visible graph. `conflicting` evidence remains visible and is never automatically resolved.

## Approved provider payloads

The provider boundary intentionally does not prescribe or guess an official URL, XML operation, authentication scheme, or credential. A lawful adapter returns transport-neutral data to the importer.

The commercial importer accepts a company record with `eik`, `legal_name`, status/registration/liquidation/insolvency facts, material circumstances, and arrays for `managers`, `owners`, and `beneficial_owners`. Relationship entries carry source references, source/validity dates, current state, and narrow evidence such as representation or ownership percentage.

The Property Register importer accepts a `property_identifier`, an explicit electronic-coverage statement, and registered-owner entries with their own source record references and dates. Incomplete history must include a limitation and is presented as incomplete.

See [the synthetic test-property graph](examples/property-graph.json). It demonstrates the contract and UI shape; it is not live registry data.
