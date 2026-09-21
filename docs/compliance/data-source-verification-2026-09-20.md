# Data-source verification — 20 September 2026

This evidence was collected from the development workspace using live source connectivity and the local prepared-data database. “Success” proves technical access, not legal permission. Production permission remains controlled independently.

## Live connectivity

| Check | Result |
| --- | --- |
| SofiaPlan API version | Success; API version 1.0 returned. |
| SofiaPlan catalogue | Success; live catalogue returned. |
| SofiaPlan ArcGIS layer 31 — development potential | Success; FeatureServer metadata returned. |
| SofiaPlan ArcGIS layer 33 — functional zoning | Success; FeatureServer metadata returned. |
| NAG building permits | HTTP 200. |
| NAG design visas | HTTP 200. |
| NAG urban-planning orders | HTTP 200. |
| NAG occupancy certificates | HTTP 200. |
| OpenStreetMap Overpass | Success; bounded coverage query returned 67 relevant source features. |
| KAIS OpenData portal | HTTP 200; HTML portal available. This check does not download an archive. |
| European Commission VIES | Success for exact EIK 208282493; response confirmed `vat_valid=false` on the check date. |

Re-run the task to capture the result at deployment time; network state is not frozen by this note.

## Prepared local records

| Dataset | Records | Last completed import (UTC) | Permission at verification |
| --- | ---: | --- | --- |
| SofiaPlan schools | 275 | 2026-09-10 08:56:29 | `review_required` |
| SofiaPlan kindergartens | 397 | 2026-09-10 08:56:31 | `review_required` |
| SofiaPlan parks/green spaces | 929 | 2026-09-10 08:56:36 | `review_required` |
| SofiaPlan metro/transit | 78 | 2026-09-10 08:56:37 | `review_required` |
| SofiaPlan flood risk | 40 | 2026-09-10 08:56:37 | `review_required` |
| ArcGIS development potential | 40 | 2026-09-10 08:56:30 | `review_required` |
| ArcGIS functional zoning | 40 | 2026-09-10 08:56:31 | `review_required` |
| OpenStreetMap amenities | 50 stored features (67 rows observed in source snapshot) | 2026-09-10 08:56:30 | `approved` |

KAIS controlled imports existed for the three legal-entity rights workbooks in district Студентски:

- building rights: 1,380 rows seen; 650 imported; 730 natural-person rows omitted;
- individual-object rights: 63,668 rows seen; 19,632 imported; 4,345 duplicates; 39,691 natural-person rows omitted;
- parcel rights: 30,296 rows seen; 5,417 imported; 35 duplicates; 24,844 natural-person rows omitted.

The parcel, building, and individual-object geometry archives were catalogued but had no completed import in the captured database. All six archive permissions were `review_required`; no production use is authorised by these imports.

NAG prepared snapshots from 10–11 September 2026 showed that the bounded exact-identifier integration executed successfully. Snapshot record counts varied between zero and one for the tested identifier, which is expected and must never be described as proof that an act does not exist.

## Enforcement verified in code

- Production ingestion raises unless the source or exact cadastral archive has `approved` permission.
- Production reads use only `SpatialDataset.usable`, approved cadastral archive keys, and approved rights archive keys.
- NAG does not reuse old snapshots in production while its permission is unsettled.
- Commercial Register and Property Register providers remain unavailable by default.
- VIES runs only when an exact checksum-valid EIK has already been established.
- Cadastral rights importer drops natural-person rows before persistence.
- Raw per-report source responses are disabled by default (`STORE_RAW_SOURCE_RESPONSES=false`).

## Reproduction

```sh
bin/rails data_sources:check
bin/rails coverage:status
```

Archive both outputs with the release record. Do not run bulk synchronisation in production merely to test access; the permission gate is expected to reject unsettled sources.
