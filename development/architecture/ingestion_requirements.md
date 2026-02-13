# Ingestion specifications

To populate the variables_raw table in DuckDB, we use a **Tiered Ingestion Strategy**. We prioritise structured metadata (DDI XML) where available (PUMF), and fall back to documentation parsing for restricted files (Master).

## 1. Source tagging & provenance

Every row in the database tracks *how* the information was obtained.

* **source_method = 'DDI_XML'**: Parsed from Data Documentation Initiative XML. (Gold Standard - Contains Logic & Text)
* **source_method = 'DATA_SCAN'**: Extracted directly from a .sav or .dta file header. (Silver Standard - Contains Values but no Logic)
* **source_method = 'PDF_PARSE'**: Extracted via OCR/Text from PDF Guide. (Bronze Standard)

## 2. Methodology A: DDI XML parsing (primary for PUMF)

**Target:** PUMF DDI XML files (standard StatCan delivery).

**Tools:** Python (lxml), R (xml2, ddi4r).

**Why this is better:** DDI contains the *context* of the variable, not just the code.

### Extraction logic

We parse the `<var>` nodes in the XML document.

1. **Variable Metadata:**
   * Name: from `<var name="...">`.
   * Label: from `<labl>`.
2. **Rich Context (The "Killer Feature"):**
   * **Question Text:** Extract from `<qstn><qstnLit>`. This allows the Agent to read *exactly* what the respondent was asked.
   * **Universe/Skip Logic:** Extract from `<universe>`. Tells the Agent *who* was asked (e.g., "Respondents aged 12+ who smoked in last 30 days").
   * **Notes:** Extract from `<txt>` or `<notes>`.
3. **Categories:**
   * Iterate through `<catgry>` nodes.
   * Map `<catValu>` (Code) to `<labl>` (Label).
   * Store as categories_json.

**Pseudo-code (Python):**

```python
from lxml import etree

def parse_ddi(xml_path):
    tree = etree.parse(xml_path)
    ns = {'ddi': 'http://www.icpsr.umich.edu/DDI'}

    variables = []
    for var in tree.xpath('//ddi:var', namespaces=ns):
        # Basics
        name = var.get('name')
        label = var.xpath('./ddi:labl/text()', namespaces=ns)[0]

        # Rich Text
        question = var.xpath('./ddi:qstn/ddi:qstnLit/text()', namespaces=ns)
        universe = var.xpath('./ddi:universe/text()', namespaces=ns)

        # Categories
        cats = {}
        for cat in var.xpath('./ddi:catgry', namespaces=ns):
            code = cat.xpath('./ddi:catValu/text()', namespaces=ns)[0]
            labl = cat.xpath('./ddi:labl/text()', namespaces=ns)[0]
            cats[code] = labl

        variables.append({
            "variable_name": name,
            "label_en": label,
            "question_text": question[0] if question else None,
            "universe_logic": universe[0] if universe else None,
            "categories_json": cats,
            "source_method": "DDI_XML",
            "file_type": "PUMF"
        })
    return variables
```

## 3. Methodology B: Direct data scanning (secondary)

**Target:** Verification of PUMF files.

Even with DDI, we occasionally run a **Data Scan** on the actual .sav files to calculate summary stats (min, max, distinct_count).

* **Purpose:** To verify that the DDI matches the actual data distribution (e.g., ensuring "999" actually appears in the data if the XML defines it).

## 4. Methodology C: Documentation parsing (Master files)

**Target:** Master files (No DDI available usually).

We continue to use PDF/HTML parsing for Master files.

* **Integration:** If we have a PUMF DDI variable SMKG01 (Categorical) and a Master PDF variable SMKG01 (Continuous), we store **both** in the raw_variables table, distinguished by file_type.

## 5. DuckDB load strategy

1. **Load DDI XML:** Populates raw_variables with rich text.
2. **Load Master PDF:** Adds Master-only variables.
3. **Compute Stats:** Updates min_val, max_val columns in raw_variables by scanning the .sav file (matching on variable_name).
