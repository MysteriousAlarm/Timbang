# Pilot metrics (Section 12)

Pilot: one public market + one farmer group for about 4 weeks. Admin → Pangkalahatang-tanaw →
**Sukatan ng pilot** (callable `getPilotMetrics`, aggregates only, no personal data).

| Metric | Definition | Target idea for the pilot |
|---|---|---|
| Median price age | Median of `now - latestReportAt` over all board entries; also per market with share fresh (≤ 24 h) | Under 6 h on market days at the pilot market |
| Active farmers (30 d) | Distinct farmers who posted a listing or a price report in the last 30 days, out of registered farmers | Most of the farmer group |
| Listings posted (30 d) | Listings created in the last 30 days | Grows week over week |
| Inquiries per listing | Inquiries (30 d) ÷ listings (30 d) | ≥ 1 means buyers are using it |
| Reports by source (7 d) | Official / verified reporter / community counts | Reporter + official reports every market day |

Collect weekly screenshots of this section for the CS PC 7 / IT ECC 6 report.
