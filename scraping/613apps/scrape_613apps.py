"""
Scrape CCHS variable metadata from 613apps.ca Data Dictionary Builder.

The app is a Shiny/DataTables application that displays CCHS variables with
labels, format codes, file assignments, and response categories. This script
uses Playwright to automate browser interaction, filtering by cycle year and
paginating through all results.

Supports two CCHS surveys via the --survey flag:
  - "master" (default): CCHS Master file variables
  - "pumf": CCHS PUMF variables

Usage:
    # Scrape a single cycle (headed for debugging)
    python scrape_613apps.py --cycle 2023 --headed

    # Scrape PUMF variables
    python scrape_613apps.py --cycle 2023 --survey pumf

    # Scrape all known cycles (Master)
    python scrape_613apps.py --all

    # Scrape all known cycles (PUMF)
    python scrape_613apps.py --all --survey pumf

Output:
    data/sources/613apps/raw/613apps_master_{cycle}.csv
    data/sources/613apps/raw/613apps_pumf_{cycle}.csv
"""

import argparse
import asyncio
import csv
import math
import os
import re
from pathlib import Path

from playwright.async_api import async_playwright, Page

BASE_URL = "https://613apps.ca/data-dictionary-builder/"
DEFAULT_OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "data", "sources", "613apps", "raw",
)
DELAY_BETWEEN_PAGES = 1.5  # seconds
DELAY_BETWEEN_CYCLES = 5.0  # seconds
PAGE_LOAD_TIMEOUT = 60000  # ms — Shiny apps can be slow
TABLE_RENDER_TIMEOUT = 30000  # ms

# Column indices in the DataTable (0-based)
COL_VARIABLE = 0
COL_LABEL = 1
COL_FORMAT = 2
COL_FILE = 3
COL_RESPONSE = 4

# Survey selector values (from <select#survey>)
SURVEY_OPTIONS = {
    "master": "CCHS",
    "pumf": "CCHS (PUMF)",
}


async def wait_for_overlay_clear(page: Page, timeout: int = 30000):
    """Wait for the Shiny loading overlay to disappear."""
    try:
        await page.wait_for_selector(
            "#ss-overlay", state="hidden", timeout=timeout
        )
    except Exception:
        # Overlay may not exist at all, which is fine
        pass


async def wait_for_table(page: Page):
    """Wait for the DataTable to finish rendering."""
    await wait_for_overlay_clear(page)
    await page.wait_for_selector(
        "#DataTables_Table_0 tbody tr", timeout=TABLE_RENDER_TIMEOUT
    )
    await page.wait_for_selector(
        ".dataTables_info", timeout=TABLE_RENDER_TIMEOUT
    )


async def select_survey(page: Page, survey: str):
    """Select a survey from the dropdown before building the dictionary."""
    select_el = await page.query_selector("select#survey")
    if not select_el:
        raise RuntimeError("Could not find survey selector (select#survey)")

    label = SURVEY_OPTIONS.get(survey, survey)
    print(f"Selecting survey: {label}")
    await page.select_option("select#survey", label=label)
    await asyncio.sleep(1)


async def click_build_dictionary(page: Page):
    """Click the 'Build dictionary' button and wait for the table to appear."""
    btn = await page.query_selector("#build_data_dictionary")
    if not btn:
        raise RuntimeError(
            "Could not find 'Build dictionary' button (#build_data_dictionary)"
        )
    print("Clicking 'Build dictionary'...")
    await btn.click()
    print("Waiting for table to render...")
    await wait_for_table(page)


async def get_entry_count(page: Page) -> tuple[int, int]:
    """
    Parse the DataTables info text to get filtered and total entry counts.

    Returns: (filtered_count, total_count)
    """
    info_el = await page.query_selector(".dataTables_info")
    if not info_el:
        return 0, 0
    text = await info_el.inner_text()

    # "Showing 1 to 50 of 709 entries (filtered from 6,979 total entries)"
    m = re.search(
        r"of\s+([\d,]+)\s+entries\s*\(filtered from\s+([\d,]+)\s+total",
        text,
    )
    if m:
        return int(m.group(1).replace(",", "")), int(m.group(2).replace(",", ""))

    # "Showing 1 to 50 of 6,979 entries"
    m = re.search(r"of\s+([\d,]+)\s+entries", text)
    if m:
        count = int(m.group(1).replace(",", ""))
        return count, count

    return 0, 0


async def get_column_filters(page: Page) -> list:
    """
    Get the 5 column filter inputs from the DataTable header.

    Shiny DT with filter='top' creates a second <tr> in <thead> with
    one <td> per column, each containing an <input type="search">.
    Order: Variable(0), Label(1), Format(2), File(3), Response(4).
    """
    inputs = await page.query_selector_all(
        "#DataTables_Table_0 thead tr:nth-child(2) input[type='search']"
    )
    if len(inputs) < 5:
        inputs = await page.query_selector_all(
            "#DataTables_Table_0 thead .form-control"
        )
    if len(inputs) < 5:
        raise RuntimeError(
            f"Expected 5 column filter inputs, found {len(inputs)}. "
            "Run with --headed to inspect."
        )
    return inputs


async def set_column_filter(page: Page, col_index: int, value: str):
    """Type a value into a specific column filter and wait for re-render."""
    await wait_for_overlay_clear(page)
    inputs = await get_column_filters(page)
    inp = inputs[col_index]

    await inp.click(click_count=3)
    await inp.press("Backspace")
    await asyncio.sleep(0.3)
    await inp.type(value, delay=50)

    await asyncio.sleep(2)
    await wait_for_table(page)


async def clear_column_filter(page: Page, col_index: int):
    """Clear a specific column filter."""
    await wait_for_overlay_clear(page)
    inputs = await get_column_filters(page)
    inp = inputs[col_index]
    await inp.click(click_count=3)
    await inp.press("Backspace")
    await asyncio.sleep(1)


async def clear_all_filters(page: Page):
    """Clear all column filter inputs."""
    inputs = await get_column_filters(page)
    for inp in inputs:
        val = await inp.input_value()
        if val:
            await inp.click(click_count=3)
            await inp.press("Backspace")
            await asyncio.sleep(0.3)
    await asyncio.sleep(2)
    await wait_for_table(page)


async def extract_table_rows(page: Page) -> list[dict]:
    """
    Extract all visible rows from the DataTable.

    Uses inner_text() which converts <br> tags to newlines,
    preserving line breaks in the Response column.
    """
    rows = []
    tr_elements = await page.query_selector_all(
        "#DataTables_Table_0 tbody tr"
    )

    for tr in tr_elements:
        tds = await tr.query_selector_all("td")
        if len(tds) < 5:
            continue

        row = {
            "Variable": (await tds[COL_VARIABLE].inner_text()).strip(),
            "Label": (await tds[COL_LABEL].inner_text()).strip(),
            "Format": (await tds[COL_FORMAT].inner_text()).strip(),
            "File": (await tds[COL_FILE].inner_text()).strip(),
            "Response": (await tds[COL_RESPONSE].inner_text()).strip(),
        }
        rows.append(row)

    return rows


async def has_next_page(page: Page) -> bool:
    """Check if the Next pagination button is enabled."""
    next_li = await page.query_selector(
        ".dataTables_paginate li.paginate_button.next:not(.disabled)"
    )
    return next_li is not None


async def go_to_next_page(page: Page):
    """Click Next and wait for the table to update."""
    next_li = await page.query_selector(
        ".dataTables_paginate li.paginate_button.next a"
    )
    if not next_li:
        next_li = await page.query_selector(
            ".dataTables_paginate li.paginate_button.next"
        )
    if not next_li:
        raise RuntimeError("Next button not found")

    first_td = await page.query_selector(
        "#DataTables_Table_0 tbody tr:first-child td:first-child"
    )
    old_text = await first_td.inner_text() if first_td else ""

    await next_li.click()

    for _ in range(30):
        await asyncio.sleep(0.2)
        first_td = await page.query_selector(
            "#DataTables_Table_0 tbody tr:first-child td:first-child"
        )
        new_text = await first_td.inner_text() if first_td else ""
        if new_text != old_text:
            break


async def go_to_first_page(page: Page):
    """Navigate to the first page of results."""
    first_li = await page.query_selector(
        ".dataTables_paginate li.paginate_button.first a"
    )
    if first_li:
        await first_li.click()
        await asyncio.sleep(1)
        return

    page_one = await page.query_selector(
        ".dataTables_paginate li.paginate_button:not(.previous):not(.next) a"
    )
    if page_one:
        text = await page_one.inner_text()
        if text.strip() == "1":
            await page_one.click()
            await asyncio.sleep(1)
            return

    active = await page.query_selector(
        ".dataTables_paginate li.paginate_button.active"
    )
    if active:
        text = await active.inner_text()
        if text.strip() == "1":
            return


async def scrape_cycle(
    page: Page, cycle: str, output_dir: str, delay: float,
    survey: str = "master",
) -> str:
    """
    Scrape all pages for a single cycle year.
    Returns the path to the output CSV file.
    """
    print(f"\n{'='*60}")
    print(f"Scraping cycle: {cycle} ({survey})")
    print(f"{'='*60}")

    await set_column_filter(page, COL_FILE, cycle)

    filtered, total = await get_entry_count(page)
    print(f"  Filtered entries: {filtered} (of {total} total)")

    if filtered == 0:
        print(f"  No entries found for cycle {cycle}, skipping.")
        return ""

    await go_to_first_page(page)
    await asyncio.sleep(1)

    page_size = 50
    expected_pages = math.ceil(filtered / page_size)
    print(f"  Expected pages: {expected_pages}")

    all_rows = []
    page_num = 1

    while True:
        print(
            f"  Page {page_num}/{expected_pages}: extracting rows...",
            end=" ",
            flush=True,
        )
        rows = await extract_table_rows(page)
        print(f"{len(rows)} rows")
        all_rows.extend(rows)

        if not await has_next_page(page):
            break

        await go_to_next_page(page)
        page_num += 1
        await asyncio.sleep(delay)

    print(f"  Total rows scraped: {len(all_rows)}")

    if len(all_rows) != filtered:
        print(
            f"  WARNING: Expected {filtered} rows but scraped {len(all_rows)}"
        )

    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"613apps_{survey}_{cycle}.csv")

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["Variable", "Label", "Format", "File", "Response"],
            quoting=csv.QUOTE_ALL,
        )
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"  Saved to: {output_path}")
    return output_path


async def scrape_unfiltered(
    page: Page, output_dir: str, delay: float, survey: str = "master",
) -> str:
    """
    Scrape all entries with no column filter applied.

    Paginates through the entire table as-is, producing one CSV with all
    variables and all cycles in a single pass. Useful as a cross-check
    against per-cycle scrapes.
    """
    print(f"\n{'='*60}")
    print(f"Scraping ALL entries unfiltered ({survey})")
    print(f"{'='*60}")

    filtered, total = await get_entry_count(page)
    entry_count = max(filtered, total)
    print(f"  Total entries: {entry_count}")

    await go_to_first_page(page)
    await asyncio.sleep(1)

    page_size = 50
    expected_pages = math.ceil(entry_count / page_size)
    print(f"  Expected pages: {expected_pages}")

    all_rows = []
    page_num = 1

    while True:
        print(
            f"  Page {page_num}/{expected_pages}: extracting rows...",
            end=" ",
            flush=True,
        )
        rows = await extract_table_rows(page)
        print(f"{len(rows)} rows")
        all_rows.extend(rows)

        if not await has_next_page(page):
            break

        await go_to_next_page(page)
        page_num += 1
        await asyncio.sleep(delay)

    print(f"  Total rows scraped: {len(all_rows)}")

    if len(all_rows) != entry_count:
        print(
            f"  WARNING: Expected {entry_count} rows but scraped {len(all_rows)}"
        )

    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"613apps_{survey}_all.csv")

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["Variable", "Label", "Format", "File", "Response"],
            quoting=csv.QUOTE_ALL,
        )
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"  Saved to: {output_path}")
    return output_path


async def scrape(
    cycles: list[str],
    output_dir: str,
    survey: str = "master",
    headless: bool = True,
    delay: float = DELAY_BETWEEN_PAGES,
    unfiltered: bool = False,
):
    """Main scraping function."""
    output_dir = os.path.abspath(output_dir)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=headless)
        context = await browser.new_context(
            viewport={"width": 1400, "height": 900}
        )
        page = await context.new_page()

        print(f"Navigating to {BASE_URL}")
        await page.goto(BASE_URL, timeout=PAGE_LOAD_TIMEOUT)
        await asyncio.sleep(3)

        await select_survey(page, survey)
        await click_build_dictionary(page)

        filtered, total = await get_entry_count(page)
        print(f"Table loaded. Total entries: {total}")

        if unfiltered:
            path = await scrape_unfiltered(page, output_dir, delay, survey)
            await browser.close()
            print(f"\n{'='*60}")
            print("Scraping complete!")
            print(f"{'='*60}")
            print(f"  {path}")
            return {"all": path}

        results = {}
        for i, cycle in enumerate(cycles):
            if i > 0:
                print(f"\nWaiting {DELAY_BETWEEN_CYCLES}s before next cycle...")
                await asyncio.sleep(DELAY_BETWEEN_CYCLES)
                await clear_column_filter(page, COL_FILE)
                await asyncio.sleep(2)

            try:
                path = await scrape_cycle(
                    page, cycle, output_dir, delay, survey=survey,
                )
                if path:
                    results[cycle] = path
            except Exception as e:
                print(f"  ERROR scraping cycle {cycle}: {e}")
                import traceback
                traceback.print_exc()
                try:
                    await clear_all_filters(page)
                except Exception:
                    pass

        await browser.close()

    print(f"\n{'='*60}")
    print("Scraping complete!")
    print(f"{'='*60}")
    for cycle, path in results.items():
        print(f"  {cycle}: {path}")

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Scrape 613apps.ca Data Dictionary Builder"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--cycle", help="Single cycle to scrape (e.g., '2023')")
    group.add_argument(
        "--cycles", nargs="+", help="Multiple cycles (e.g., 2023 2022 2021)"
    )
    group.add_argument(
        "--all",
        action="store_true",
        help="Scrape all known cycles",
    )
    group.add_argument(
        "--unfiltered",
        action="store_true",
        help="Scrape all entries without any column filter (single pass)",
    )

    parser.add_argument(
        "--survey",
        choices=["master", "pumf"],
        default="master",
        help="Survey to scrape: 'master' (CCHS) or 'pumf' (CCHS PUMF) (default: master)",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory for raw CSVs",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run browser in headed mode (visible)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DELAY_BETWEEN_PAGES,
        help=f"Delay between page loads in seconds (default: {DELAY_BETWEEN_PAGES})",
    )

    args = parser.parse_args()

    if args.unfiltered:
        cycles = []
    elif args.cycle:
        cycles = [args.cycle]
    elif args.cycles:
        cycles = args.cycles
    else:
        # Pre-2009 cycles use version IDs (1.1=2001, 2.1=2003, 3.1=2005, 4.1=2007-2008)
        cycles = [
            "2023", "2022", "2021",
            "2019-2020", "2017-2018", "2015-2016",
            "2013-2014", "2011-2012", "2009-2010",
            "4.1", "3.1", "2.1", "1.1",
        ]

    asyncio.run(
        scrape(
            cycles=cycles,
            output_dir=args.output_dir,
            survey=args.survey,
            headless=not args.headed,
            delay=args.delay,
            unfiltered=args.unfiltered,
        )
    )


if __name__ == "__main__":
    main()
