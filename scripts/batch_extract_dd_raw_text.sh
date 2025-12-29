#!/usr/bin/env bash
# Batch extract data dictionaries with raw text QMD companion files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$REPO_DIR/cchs-extracted/data-dictionary"

echo "=== Batch Extract Data Dictionaries with Raw Text ==="
echo ""

total=0
success=0
failed=0

process_pdf() {
    local year="$1"
    local pdf="$2"
    local pdf_path="$REPO_DIR/$pdf"
    
    if [[ ! -f "$pdf_path" ]]; then
        echo "SKIP: $year - PDF not found"
        return
    fi
    
    local year_dir="$OUTPUT_DIR/$year"
    mkdir -p "$year_dir"
    
    local output_yaml="$year_dir/cchs_${year}_dd_master.yaml"
    
    echo "[$year] Extracting..."
    total=$((total + 1))
    
    if /usr/local/bin/Rscript --vanilla "$SCRIPT_DIR/extract_data_dictionary.R" \
        "$pdf_path" \
        "$output_yaml" \
        --metadata year="$year" doc_type=master \
        --raw-text 2>&1 | grep -E "(Found|written|Generating)"; then
        success=$((success + 1))
        echo "[$year] ✓ Done"
    else
        failed=$((failed + 1))
        echo "[$year] ✗ FAILED"
    fi
    echo ""
}

# Process each year
process_pdf "2007-2008" "cchs-osf-docs/2007/24-Month/Master/Docs/CCHS_2007-2008_DataDictionary_Freq.pdf"
process_pdf "2009" "cchs-osf-docs/2009/12-Month/Master/Docs/CCHS_2009_DataDictionary_Freq.pdf"
process_pdf "2010" "cchs-osf-docs/2010/12-Month/Master/Docs/CCHS_2010_DataDictionary_Freqs.pdf"
process_pdf "2011" "cchs-osf-docs/2011/12-Month/Master/Docs/CCHS_2011_DataDictionary_Freqs.pdf"
process_pdf "2012" "cchs-osf-docs/2012/12-Month/Master/Docs/CCHS_2012_DataDictionary_Freqs.pdf"
process_pdf "2013" "cchs-osf-docs/2013/12-Month/Master/Docs/CCHS_2013_DataDictionary_Freqs.pdf"
process_pdf "2014" "cchs-osf-docs/2014/12-Month/Master/Docs/CCHS_2014_DataDictionary_Freqs.pdf"
process_pdf "2015" "cchs-osf-docs/2015/12-Month/Master/Docs/CCHS_2015_DataDictionary_Freqs.pdf"
process_pdf "2016" "cchs-osf-docs/2016/12-Month/Master/Docs/CCHS_2016_DataDictionary_Freqs.pdf"
process_pdf "2017" "cchs-osf-docs/2017/12-Month/Master/Docs/CCHS_2017_DataDictionary_Freqs.pdf"
process_pdf "2018" "cchs-osf-docs/2018/12-Month/Master/Docs/CCHS_2018_DataDictionary_Freqs.pdf"
process_pdf "2019" "cchs-osf-docs/2019/12-Month/Master/Docs/CCHS_2019_DataDictionary_Freqs.pdf"
process_pdf "2020" "cchs-osf-docs/2020/12-Month/Master/Docs/CCHS_2020_DataDictionary_Freqs.pdf"
process_pdf "2021" "cchs-osf-docs/2021/12-Month/Master/Docs/CCHS_2021_DataDictionary_Freqs.pdf"
process_pdf "2022" "cchs-osf-docs/2022/12-Month/Master/Docs/CCHS_2022_DataDictionary_Freqs.pdf"
process_pdf "2023" "cchs-osf-docs/2023/12-Month/Master/Docs/CCHS_2023_DataDictionary_Freqs.pdf"

echo "=== Summary ==="
echo "Total: $total"
echo "Success: $success"
echo "Failed: $failed"
