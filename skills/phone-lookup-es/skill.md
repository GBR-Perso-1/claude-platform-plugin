---
name: phone-lookup-es
description: >
  Look up a Spanish phone number. Normalises the input, classifies it as
  mobile or landline (with region), queries listaspam.com, responderono.es,
  and a general web search, then renders a structured SPAM / LEGITIMATE /
  INCONCLUSIVE verdict with evidence.
tools:
  - WebSearch
  - mcp__claude-in-chrome__tabs_context_mcp
  - mcp__claude-in-chrome__tabs_create_mcp
  - mcp__claude-in-chrome__navigate
  - mcp__claude-in-chrome__get_page_text
---

## Important rules

Read and follow all rules in [`../shared/_ux-rules.md`](../shared/_ux-rules.md).

## Input

`$ARGUMENTS` is the phone number to look up.

If `$ARGUMENTS` is empty, ask via `AskUserQuestion`:
- Question: "Which Spanish phone number would you like to look up?"
- Single option: `I'll type it` (user provides free-text via the automatic Other input)

Use the text entered by the user as the number to process.

---

### Phase 1 — Normalise and validate

1. Take the raw input.
2. Strip a leading `+34` or `0034` prefix if present.
3. Remove all spaces, dots, dashes, and parentheses.
4. The result must be exactly 9 digits.
   - If it is not, print a clear error in this format and **halt**:

     ```
     Error: could not normalise input.
     Original input : <raw input>
     Normalised result: <what remained after stripping>
     Expected: exactly 9 digits after stripping the country prefix and non-digit characters.
     ```

5. Store the 9-digit string as `NUMBER`.

---

### Phase 2 — Classify

Match against the first digit(s) of `NUMBER`:

| Pattern | Type |
|---|---|
| `6xx` or `7xx` | Mobile |
| `9xx` | Landline — apply region lookup below |
| Anything else | Unrecognised |

**Region lookup (first 3 digits, landlines only):**

| Prefix range | Region |
|---|---|
| 910 | Non-geographic (special services) |
| 911–919 | Madrid |
| 930–939 | Barcelona |
| 940–949 | Basque Country |
| 950–959 | Andalusia |
| 960–969 | Valencia |
| 971 | Balearic Islands |
| 972 | Girona |
| 973 | Lleida |
| 974 | Huesca |
| 975 | Soria |
| 976–977 | Zaragoza / Tarragona |
| 978 | Teruel |
| 979 | Palencia |
| 970 | Unrecognised area |
| 980–989 | Galicia / Asturias |
| 900 | Freephone (national) |
| 901–902 | Shared-cost (national) |
| Other 9xx | Unrecognised area |

Store the classification as `TYPE` and, for landlines, `REGION`.

---

### Phase 3 — Fetch sources

Fetch all three sources. A per-source failure (network error, empty response, unexpected page) must be recorded as `"No data (fetch failed)"` — never halt the skill.

### Source A — listaspam.com

Use Claude in Chrome to load the page (bypasses the 403 that `WebFetch` receives):

1. Call `mcp__claude-in-chrome__tabs_context_mcp` (with `createIfEmpty: true`) to get a valid tab context.
2. Call `mcp__claude-in-chrome__tabs_create_mcp` to open a fresh tab.
3. Call `mcp__claude-in-chrome__navigate` with the new tab ID and URL `https://www.listaspam.com/busca.php?Telefono=NUMBER`.
4. Call `mcp__claude-in-chrome__get_page_text` on the same tab.
5. From the returned text extract:
   - **REPORT_COUNT_A** — the number next to `DENUNCIAS` (treat as 0 if missing or non-numeric)
   - **SEARCH_COUNT_A** — the number next to `BÚSQUEDAS` (treat as 0 if missing or non-numeric)
   - **Most recent report date** — if present
   - **Up to 3 user comments** — if present
6. If any step fails (tool error, page not found, unexpected content), record Source A as `"No data (fetch failed)"` and set `REPORT_COUNT_A = 0`, `SEARCH_COUNT_A = 0`.

### Source B — responderono.es

- URL: `https://www.responderono.es/numero/NUMBER`
- Use `WebFetch` with this extraction prompt:
  > "Extract: total number of reports or ratings, the caller type label (e.g. spam, telemarketing, unknown), and up to 3 user comments. If a field is not present, return 'not found'."

### Source C — web search

- Before constructing the query, format `NUMBER` as three groups of three digits separated by spaces: `XXX XXX XXX`. For example, `930510240` becomes `930 510 240`.
- Query: `"XXX XXX XXX" España OR Spain` (using the space-formatted number inside the quotes)
- Use `WebSearch` and collect the top 3–5 results.
- For each result record: title, URL, snippet.

---

### Phase 4 — Determine verdict

1. Parse the report counts from Source A and Source B.
   - If a count is missing or non-numeric, treat it as 0.
   - Sum them as `COMBINED_COUNT`.

2. Read `SEARCH_COUNT_A` (the listaspam.com search count extracted in Source A).
   - Set `HIGH_SEARCH_ACTIVITY = true` if `SEARCH_COUNT_A ≥ 5`, otherwise `false`.

3. Check Source C results for scam-related keywords: `estafa`, `fraude`, `scam`, `phishing`, `llamada automática`, `llamadas fraudulentas`, `timo`.

4. Apply the following rules in order (first match wins):

| Rule | Condition | Verdict |
|---|---|---|
| 1 | `COMBINED_COUNT ≥ 5` OR Source C contains any scam keyword | **SPAM** |
| 2 | `COMBINED_COUNT = 0` AND `HIGH_SEARCH_ACTIVITY = false` AND neither Source A nor Source B produced a `"No data (fetch failed)"` result AND Source C identifies a known business or institution | **LEGITIMATE** |
| 3 | Everything else | **INCONCLUSIVE** |

Store as `VERDICT`.

> **Note on search count:** A high `SEARCH_COUNT_A` (≥ 5) with zero reports is a soft red flag — it means multiple people received a call and went to look up the number, even if none filed a formal complaint. Always surface the raw search count in the Evidence section and call it out explicitly in the Guidance when `HIGH_SEARCH_ACTIVITY = true`.

---

### Phase 5 — Render output

Produce the following report. Omit the Region row entirely for mobile and unrecognised numbers.

```
## Number Info
| Field | Value |
|---|---|
| Normalised number | `NUMBER` |
| Type | `TYPE` |
| Region | `REGION` |

## Verdict
> **VERDICT**

## Evidence

### listaspam.com
[SOURCE_A findings or "No data (fetch failed)"]

### responderono.es
[SOURCE_B findings or "No data (fetch failed)"]

### Web search
[SOURCE_C as a bulleted list: [Title](URL) — snippet]
[Or "No results found" if nothing was returned]

## Guidance
[Guidance paragraph for the verdict — see below]
```

**Guidance paragraphs by verdict:**

- **SPAM** — "This number has been flagged as spam (either through community reports or web evidence). Do not call back. If they asked for personal details, account credentials, or for you to install software, treat this as a scam."
- **LEGITIMATE** — "This number appears to belong to a legitimate organisation. It is likely safe to return the call."
- **INCONCLUSIVE** — "There is not enough evidence to classify this number. Exercise caution — do not provide personal or financial information if called back."

**Search count addendum (append to Guidance whenever `HIGH_SEARCH_ACTIVITY = true`):**

> ⚠️ Note: **SEARCH_COUNT_A people** have looked this number up on listaspam.com without filing a formal report. This pattern is consistent with an unsolicited caller — people rarely search numbers they dialled themselves. Treat any callback with extra caution.

If all three sources failed (all returned "No data (fetch failed)" or no results), state this clearly before the verdict:

> All three sources failed to return data. The verdict is based on absence of evidence only.

---

## Conversation Style

- Factual and neutral — present what sources say, do not editorialise.
- British English throughout.
- Do not speculate beyond the source data.
