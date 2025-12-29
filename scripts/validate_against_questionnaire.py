#!/usr/bin/env python3
"""
Validate data dictionary extraction against questionnaire (triangulation).

Questionnaires provide an independent source for validating:
- Variable presence (matching codes like SMK_005)
- Question text consistency
- Response option labels (where available)

This complements DDI validation for Master files where DDI is not available.

Usage:
    python validate_against_questionnaire.py <questionnaire_yaml> <extracted_yaml> [--output report.txt]

Requires: pyyaml
"""

import argparse
import re
import sys
from pathlib import Path

import yaml


def load_yaml(path: str) -> dict:
    """Load YAML file."""
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def normalize_text(text: str) -> str:
    """Normalize text for comparison (whitespace, case, punctuation)."""
    if not text:
        return ''
    # Remove common variations
    text = text.replace('\n', ' ')
    text = text.replace('  ', ' ')
    # Normalize quotes
    text = text.replace('\u2018', "'").replace('\u2019', "'")
    text = text.replace('\u201C', '"').replace('\u201D', '"')
    # Normalize whitespace and case
    return ' '.join(text.lower().split())


def extract_core_question(text: str) -> str:
    """Extract the core question text, removing prefixes like 'SMK_Q005:'."""
    if not text:
        return ''
    # Remove leading variable codes (e.g., "SMK_Q005:")
    text = re.sub(r'^[A-Z]{2,4}_[A-Z]?\d+:\s*', '', text)
    return text.strip()


def compute_text_similarity(text1: str, text2: str) -> float:
    """Compute word-level Jaccard similarity between two texts."""
    if not text1 or not text2:
        return 0.0

    words1 = set(normalize_text(text1).split())
    words2 = set(normalize_text(text2).split())

    if not words1 or not words2:
        return 0.0

    intersection = len(words1 & words2)
    union = len(words1 | words2)

    return intersection / union if union > 0 else 0.0


def parse_questionnaire(data: dict) -> dict:
    """Extract questions from questionnaire YAML.

    Questionnaires have codes like SMK_Q005, SMK_005, etc.
    We extract the base code (e.g., SMK_005) for matching.
    """
    questions = data.get('questions', {})
    parsed = {}

    for code, q in questions.items():
        if not isinstance(q, dict):
            continue

        # Extract base code (remove Q, R, C, D, E, B prefixes)
        # SMK_Q005 -> SMK_005, GEN_R01 -> GEN_01
        base_code = re.sub(r'^([A-Z]{2,4}_)[QRCDEB](\d+)', r'\1\2', code)

        # Skip flow control items (usually have no question text)
        question_text = q.get('question_text', '')
        if not question_text or question_text == '.na':
            continue

        # Skip interviewer-only items
        if q.get('question_type') == 'interviewer':
            continue

        # Extract response options
        options = []
        for opt in q.get('response_options', []):
            if isinstance(opt, dict) and opt.get('label'):
                options.append({
                    'value': opt.get('value'),
                    'label': opt.get('label', '')
                })

        # Store under base code (may overwrite, prefer Q version)
        if base_code not in parsed or code.startswith(base_code.split('_')[0] + '_Q'):
            parsed[base_code] = {
                'code': base_code,
                'original_code': code,
                'question_text': extract_core_question(question_text),
                'section': q.get('section', ''),
                'section_code': q.get('section_code', ''),
                'response_options': options
            }

    return parsed


def parse_data_dictionary(data: dict) -> dict:
    """Extract variables from data dictionary YAML."""
    variables = data.get('variables', {})
    parsed = {}

    for name, var in variables.items():
        if not isinstance(var, dict):
            continue

        parsed[name] = {
            'name': name,
            'label': var.get('label', ''),
            'question_text': var.get('question_text', ''),
            'categories': var.get('categories', [])
        }

    return parsed


def is_multi_response_item(code: str) -> tuple:
    """Check if code is a multi-response sub-item (ends in letter A-Z).

    Returns (is_multi, base_code, suffix) tuple.
    Examples:
        ACC_015A -> (True, 'ACC_015', 'A')
        ACC_015 -> (False, 'ACC_015', '')
        GEN_005 -> (False, 'GEN_005', '')
    """
    # Match codes ending in letter (but not Q, R, C, D, E, B prefixes)
    match = re.match(r'^([A-Z]{2,4}_\d+)([A-Z])$', code)
    if match:
        return True, match.group(1), match.group(2)
    return False, code, ''


def validate(questionnaire: dict, data_dict: dict) -> tuple:
    """Validate data dictionary against questionnaire."""
    summary = {
        'quest_count': len(questionnaire),
        'dd_count': len(data_dict),
        'matched': 0,
        'quest_only': 0,
        'dd_only': 0,
        'text_high_similarity': 0,
        'text_medium_similarity': 0,
        'text_low_similarity': 0,
        'multi_response_matched': 0,
        'option_matches': 0,
        'option_mismatches': 0
    }

    issues = []
    matches = []

    quest_codes = set(questionnaire.keys())
    dd_codes = set(data_dict.keys())

    # Find matching codes
    matched = quest_codes & dd_codes
    quest_only = quest_codes - dd_codes
    dd_only = dd_codes - quest_codes

    summary['matched'] = len(matched)
    summary['quest_only'] = len(quest_only)
    summary['dd_only'] = len(dd_only)

    # Analyze matches
    for code in sorted(matched):
        q = questionnaire[code]
        d = data_dict[code]

        # Check if this is a multi-response item
        is_multi, base_code, suffix = is_multi_response_item(code)

        # Compare question text
        q_text = q.get('question_text', '')
        d_text = d.get('question_text', '') or d.get('label', '')

        # For multi-response items, questionnaire text is often the response option
        # (e.g., "01 Difficulty getting a referral") while DD has:
        # - label: "Difficulty specialist - getting a referral"
        # - question_text: parent question like "What types of difficulties..."
        # - categories: Yes/No (not the response text)
        # Compare questionnaire text against DD label for these items.
        if is_multi and q_text:
            # Extract just the label part (remove leading numbers)
            q_label = re.sub(r'^\d+\s+', '', q_text).strip()
            d_label = d.get('label', '')

            # Check similarity between questionnaire response option and DD label
            label_similarity = compute_text_similarity(q_label, d_label)

            if label_similarity >= 0.4:
                summary['multi_response_matched'] += 1
                summary['text_high_similarity'] += 1
                matches.append({
                    'code': code,
                    'similarity': label_similarity,
                    'quest_text': q_text[:100],
                    'dd_text': d_label[:100],
                    'section': q.get('section', ''),
                    'multi_response': True
                })
                continue

        similarity = compute_text_similarity(q_text, d_text)

        match_info = {
            'code': code,
            'similarity': similarity,
            'quest_text': q_text[:100] if q_text else '',
            'dd_text': d_text[:100] if d_text else '',
            'section': q.get('section', '')
        }

        if similarity >= 0.6:
            summary['text_high_similarity'] += 1
        elif similarity >= 0.3:
            summary['text_medium_similarity'] += 1
            match_info['issues'] = ['Medium text similarity']
        else:
            summary['text_low_similarity'] += 1
            match_info['issues'] = ['Low text similarity']

        # Compare response options where available
        q_options = q.get('response_options', [])
        d_cats = d.get('categories', [])

        if q_options and d_cats:
            q_labels = {str(o.get('value')): normalize_text(o.get('label', ''))
                       for o in q_options if o.get('value') not in ['NO_DK_RF', 'DK', 'RF']}
            d_labels = {str(c.get('value')): normalize_text(c.get('label', ''))
                       for c in d_cats}

            common_values = set(q_labels.keys()) & set(d_labels.keys())
            if common_values:
                label_match = True
                for val in common_values:
                    if q_labels[val] != d_labels[val]:
                        label_match = False
                        break

                if label_match:
                    summary['option_matches'] += 1
                else:
                    summary['option_mismatches'] += 1
                    if 'issues' not in match_info:
                        match_info['issues'] = []
                    match_info['issues'].append('Response option label mismatch')

        matches.append(match_info)

    # Report issues
    issues.append(f"\n=== Variables in questionnaire only ({len(quest_only)}) ===")
    for code in sorted(list(quest_only)[:30]):
        q = questionnaire[code]
        issues.append(f"  {code}: {q.get('question_text', '')[:60]}")
    if len(quest_only) > 30:
        issues.append(f"  ... and {len(quest_only) - 30} more")

    issues.append(f"\n=== Variables in data dictionary only ({len(dd_only)}) ===")
    issues.append("  (This is expected - DD includes derived variables not in questionnaire)")

    # Report detailed comparison for matched variables with issues
    problem_matches = [m for m in matches if m.get('issues')]
    if problem_matches:
        issues.append(f"\n=== Matched variables with issues ({len(problem_matches)}) ===")
        for m in problem_matches[:50]:
            issues.append(f"\n{m['code']} (similarity: {m['similarity']:.2f}):")
            issues.append(f"  Questionnaire: {m['quest_text']}")
            issues.append(f"  Data dict:     {m['dd_text']}")
            for issue in m.get('issues', []):
                issues.append(f"  -> {issue}")

    return summary, issues


def main():
    parser = argparse.ArgumentParser(description='Validate data dictionary against questionnaire')
    parser.add_argument('questionnaire_yaml', help='Path to questionnaire YAML file')
    parser.add_argument('extracted_yaml', help='Path to extracted data dictionary YAML')
    parser.add_argument('--output', '-o', help='Output report file (default: stdout)')
    parser.add_argument('--quiet', '-q', action='store_true', help='Only show summary')

    args = parser.parse_args()

    print(f"Loading questionnaire: {args.questionnaire_yaml}")
    quest_data = load_yaml(args.questionnaire_yaml)
    questionnaire = parse_questionnaire(quest_data)
    print(f"  Found {len(questionnaire)} questions with text")

    print(f"Loading data dictionary: {args.extracted_yaml}")
    dd_data = load_yaml(args.extracted_yaml)
    data_dict = parse_data_dictionary(dd_data)
    print(f"  Found {len(data_dict)} variables")

    summary, issues = validate(questionnaire, data_dict)

    # Build report
    report = []
    report.append("=" * 70)
    report.append("QUESTIONNAIRE TRIANGULATION REPORT")
    report.append("=" * 70)
    report.append("")
    report.append(f"Questionnaire:  {args.questionnaire_yaml}")
    report.append(f"Data dictionary: {args.extracted_yaml}")
    report.append("")
    report.append("=== Summary ===")
    report.append(f"Questionnaire questions: {summary['quest_count']}")
    report.append(f"Data dict variables:     {summary['dd_count']}")
    report.append(f"Matched by code:         {summary['matched']}")
    report.append(f"Questionnaire only:      {summary['quest_only']}")
    report.append(f"Data dict only:          {summary['dd_only']}")
    report.append("")
    report.append("=== Text Similarity (matched variables) ===")
    report.append(f"High (>=60%):           {summary['text_high_similarity']}")
    if summary['multi_response_matched'] > 0:
        report.append(f"  (incl. multi-response: {summary['multi_response_matched']})")
    report.append(f"Medium (30-60%):        {summary['text_medium_similarity']}")
    report.append(f"Low (<30%):             {summary['text_low_similarity']}")
    report.append("")

    if summary['option_matches'] + summary['option_mismatches'] > 0:
        report.append("=== Response Option Comparison ===")
        report.append(f"Options match:    {summary['option_matches']}")
        report.append(f"Options mismatch: {summary['option_mismatches']}")
        report.append("")

    # Calculate match rates
    if summary['matched'] > 0:
        high_rate = summary['text_high_similarity'] / summary['matched'] * 100
        report.append(f"High similarity rate: {high_rate:.1f}%")

    if not args.quiet:
        report.extend(issues)

    report_text = '\n'.join(report)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report_text)
        print(f"\nReport written to: {args.output}")
    else:
        print(report_text)

    # Exit with error if low match rate
    if summary['matched'] > 0:
        high_rate = summary['text_high_similarity'] / summary['matched'] * 100
        if high_rate < 50:
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
