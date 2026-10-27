#!/usr/bin/env python3
"""Validate source or extracted RootHide control fields, including injector dependency."""
from pathlib import Path
import argparse
from email import policy
from email.parser import Parser
import re

ROOT = Path(__file__).resolve().parents[1]


def validate_roothide_control(text: str) -> None:
    message = Parser(policy=policy.default).parsestr(text)
    if message.defects or str(message.get_payload()).strip():
        raise ValueError('RootHide control must contain one valid metadata paragraph')
    fields = {}
    for key, value in message.items():
        key = key.lower()
        if key in fields:
            raise ValueError(f'duplicate RootHide control field: {key}')
        fields[key] = str(value).strip()
    if fields.get('package') != 'com.hydra.tlinkios' or fields.get('name') != 'TLinkIOS (RootHide)':
        raise ValueError('RootHide package identity/name is incorrect')
    if fields.get('architecture') != 'iphoneos-arm64e':
        raise ValueError('RootHide package architecture must be iphoneos-arm64e')
    depends = fields.get('depends', '')
    groups = [group.strip() for group in depends.split(',')]
    if not any(re.fullmatch(r'ellekit(?:\s*\([^()]+\))?', group) for group in groups):
        raise ValueError('RootHide must depend directly on ElleKit')
    if not any(re.fullmatch(r'firmware\s*\(>=\s*15\.0\)', group) for group in groups):
        raise ValueError('RootHide minimum firmware must remain 15.0')
    dependencies = depends + ',' + fields.get('pre-depends', '')
    if re.search(r'(?<![\w.+-])mobilesubstrate(?=$|[\s(:,|])', dependencies, re.I):
        raise ValueError('RootHide must not request the legacy mobilesubstrate package name')


def source_contracts():
    source = (ROOT / 'control.roothide').read_text(encoding='utf-8')
    validate_roothide_control(source)
    rootful = (ROOT / 'control').read_text(encoding='utf-8')
    assert 'Depends: firmware (>= 12.0), mobilesubstrate (>= 0.9.5000)' in rootful
    bad = [rootful,
           source.replace('ellekit', 'mobilesubstrate (>= 0.9.5000)'),
           source.replace('ellekit', 'ellekit | another-injector'),
           source.replace('iphoneos-arm64e', 'iphoneos-arm'),
           source + 'Depends: mobilesubstrate\n',
           source + 'Pre-Depends: mobilesubstrate\n']
    for candidate in bad:
        try:
            validate_roothide_control(candidate)
        except ValueError:
            continue
        raise AssertionError('RootHide package gate accepted wrong/legacy dependency metadata')
    # Accept folded dependency lines and unrelated additional package requirements.
    validate_roothide_control(source.replace(', ellekit', ',\n ellekit, example-runtime'))
    print(f'PASS: RootHide package metadata and negative controls ({len(bad)}/{len(bad)})')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--control', type=Path, help='control extracted by dpkg-deb -e; validates the actual artifact')
    args = parser.parse_args()
    if args.control:
        validate_roothide_control(args.control.read_text(encoding='utf-8'))
        print('PASS: Extracted RootHide package requests ElleKit with correct identity/architecture')
    else:
        source_contracts()
