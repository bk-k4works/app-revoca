"""Run `python -m tool.content --help` from the repository root."""
import argparse
import json
import sys
from pathlib import Path

from . import audit, batches, build, development, highschool, ingest, local, pilot, review_io, tts, validate
from .common import CONTENT, ROOT, SOURCE, read_json, require, write_json


def parser():
    root = argparse.ArgumentParser(description='기본 어휘 콘텐츠 파이프라인 S0–S7')
    commands = root.add_subparsers(dest='command', required=True)
    p = commands.add_parser('ingest', help='S0: extract the cited three-column PDF')
    p.add_argument('--pdf', type=Path, default=CONTENT / 'sources/curriculum_2022_basic.pdf')
    p.add_argument('--output', type=Path, default=SOURCE)
    p = commands.add_parser('source-check', help='Record a completed human comparison of the source')
    p.add_argument('--source', type=Path, default=SOURCE)
    p.add_argument('--reviewer', required=True)
    p.add_argument('--note', required=True)
    p = commands.add_parser('pilot-prepare', help='Prepare a stratified 100-word pilot and source comparison sheets; no API calls')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--source', type=Path, default=SOURCE)
    p = commands.add_parser('sense-issue', help='S1: issue an immutable sense ID')
    p.add_argument('--headword', required=True)
    p.add_argument('--pos', required=True, choices=list(build.POS_KO))
    p.add_argument('--slug', required=True)
    p.add_argument('--additional', action='store_true', help='Issue an additional sense without changing the primary')
    p = commands.add_parser('sense-retire')
    p.add_argument('--old', required=True)
    p.add_argument('--successor', required=True)
    p = commands.add_parser('gold-promote', help='Use verified human-approved records as prompt examples')
    p.add_argument('--input', type=Path, required=True)
    for name in ['local-draft-import', 'local-review-import', 'local-review-preview']:
        p = commands.add_parser(name, help='Import Codex-authored work without external API calls')
        p.add_argument('--input', type=Path, required=True)
        p.add_argument('--output', type=Path, required=True)
        p.add_argument('--source', type=Path, default=SOURCE)
        if name == 'local-review-import':
            p.add_argument('--reviews', type=Path, required=True)
    for stage in ['generate', 'review']:
        p = commands.add_parser(stage, help=f'Prepare {stage} batch requests without API calls')
        p.add_argument('--output', required=True, type=Path)
        p.add_argument('--input', type=Path)
        p.add_argument('--source', type=Path, default=SOURCE)
        p.add_argument('--limit', type=int, default=100)
        p.add_argument('--effort', choices=['medium', 'high'])
        p.add_argument('--only', nargs='+')
        p.add_argument('--cache-dir', type=Path)
    p = commands.add_parser('batch-submit', help='Submit paid work; requires ANTHROPIC_API_KEY')
    p.add_argument('requests', type=Path)
    p.add_argument('--adopt-batch-id')
    p = commands.add_parser('batch-status')
    p.add_argument('requests', type=Path)
    p = commands.add_parser('batch-collect')
    p.add_argument('requests', type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--results', type=Path, help='Import saved API results instead of fetching')
    p = commands.add_parser('validate')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--source', type=Path, default=SOURCE)
    for name in ['review-export', 'secondary-export', 'listen-export']:
        p = commands.add_parser(name)
        p.add_argument('--input', type=Path, required=True)
        p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('review-import')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--csv', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--approved', type=Path, default=CONTENT / 'approved/senses.jsonl')
    for name in ['secondary-import', 'listen-import']:
        p = commands.add_parser(name)
        p.add_argument('--input', type=Path, required=True)
        p.add_argument('--csv', type=Path, required=True)
        if name == 'secondary-import':
            p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('tts-plan')
    p.add_argument('--approved', type=Path, default=CONTENT / 'approved/senses.jsonl')
    p.add_argument('--output', type=Path, default=CONTENT / 'audio_manifest.jsonl')
    for name in ['tts-synthesize', 'tts-asr']:
        p = commands.add_parser(name)
        p.add_argument('--manifest', type=Path, default=CONTENT / 'audio_manifest.jsonl')
        p.add_argument('--audio-root', type=Path, default=CONTENT)
        if name == 'tts-asr':
            p.add_argument('--model', default='small')
        else:
            p.add_argument('--approved', type=Path, default=CONTENT / 'approved/senses.jsonl')
    p = commands.add_parser('build')
    p.add_argument('--approved', type=Path, default=CONTENT / 'approved/senses.jsonl')
    p.add_argument('--secondary', type=Path, required=True)
    p.add_argument('--audio-manifest', type=Path, default=CONTENT / 'audio_manifest.jsonl')
    p.add_argument('--audio-root', type=Path, default=CONTENT)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--version', required=True)
    p.add_argument('--expected-count', type=int, default=300)
    p.add_argument('--audio-base-url')
    p.add_argument('--frequency-ranks', type=Path, help='Optional licensed internal {headword: rank} JSON, never distributed')
    p = commands.add_parser('audit', help='List new/changed content and affected quiz choices; never approves')
    p.add_argument('--package', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--previous', type=Path)
    p = commands.add_parser('dev-preview', help='Build unapproved Codex drafts for development only')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--identities', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('dev-install', help='Install a development preview; cannot replace a release')
    p.add_argument('package', type=Path)
    p.add_argument('--assets', type=Path, default=ROOT / 'assets/content')
    p = commands.add_parser('hs-source', help='High-school list: own tiers and frequency order from book headwords only')
    p.add_argument('--entries', type=Path, default=CONTENT / 'imports/pdf-books-v1/entries.jsonl')
    p.add_argument('--output', type=Path, default=highschool.HS_SOURCE)
    p = commands.add_parser('hs-draft', help='Convert authored high-school rows and run automatic checks')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('hs-preview', help='Build a development package for the high-school track')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('hs-release', help='Build a release package from Codex-reviewed, human-approved senses only')
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--version', required=True)
    p = commands.add_parser('hs-review-prepare', help='Split authored rows into Codex review batches')
    p.add_argument('--pending', metavar='NAME', help='Only senses without a current verdict, into review/codex-v1/NAME')
    p = commands.add_parser('hs-review-merge', help='Join Codex verdicts to the batch manifest')
    p.add_argument('--dir', type=Path, default=None, help='Review directory (default: review/codex-v1)')
    p = commands.add_parser('hs-review-export', help='Write the human approval sheet (CSV, UTF-8 BOM)')
    p.add_argument('--output', type=Path, default=None)
    p = commands.add_parser('hs-review-import', help='Record human decisions from the approval sheet')
    p.add_argument('--csv', type=Path, required=True)
    commands.add_parser('hs-review-status', help='Count Codex coverage and human decisions')
    p = commands.add_parser('hs-review-web-export', help='Write the data file for the web approval page')
    p.add_argument('--output', type=Path, default=None)
    p = commands.add_parser('hs-review-web-import', help='Record decisions saved from the web approval page')
    p.add_argument('--json', type=Path, required=True)
    p = commands.add_parser('install')
    p.add_argument('package', type=Path)
    p.add_argument('--assets', type=Path, default=ROOT / 'assets/content')
    return root


def main(argv=None):
    args = parser().parse_args(argv)
    command = args.command
    if command == 'ingest':
        return ingest.extract(args.pdf, args.output)
    if command == 'source-check':
        return ingest.attest(args.source, args.reviewer, args.note)
    if command == 'pilot-prepare':
        return pilot.prepare(args.output, args.source)
    if command == 'local-draft-import':
        return local.import_drafts(args.input, args.output, args.source)
    if command == 'local-review-import':
        return local.import_reviews(args.input, args.reviews, args.output, args.source)
    if command == 'local-review-preview':
        return local.preview(args.input, args.output)
    if command == 'sense-issue':
        import re
        require(re.fullmatch(r'[a-z][a-z0-9-]*', args.slug), 'Use a lowercase English meaning slug')
        from .common import sources
        require(args.headword in sources(), 'Headword is absent from the source list')
        path = CONTENT / 'sense_registry.json'
        registry = read_json(path)
        previous = registry['primary'].pop(args.headword, None) if args.additional else None
        issued = review_io.allocate(registry, args.headword, args.pos, args.slug)
        if previous:
            registry['primary'][args.headword] = previous
        write_json(path, registry)
        return {'senseId': issued}
    if command == 'sense-retire':
        review_io.retire(args.old, args.successor)
        return {'retired': args.old, 'successor': args.successor}
    if command == 'gold-promote':
        from .common import write_jsonl
        approved = tts.approved_senses(args.input)
        write_jsonl(CONTENT / 'gold/approved_examples.jsonl', approved)
        return {'approvedGoldExamples': len(approved)}
    if command in {'generate', 'review'}:
        return batches.prepare(command, args.output, args.input, args.source, args.limit,
                               args.effort, args.only, args.cache_dir)
    if command == 'batch-submit':
        return batches.submit(args.requests, args.adopt_batch_id)
    if command == 'batch-status':
        return batches.status(args.requests)
    if command == 'batch-collect':
        return batches.collect(args.requests, args.output, args.results)
    if command == 'validate':
        result = validate.run(args.input, args.output, args.source)
        print(json.dumps(result, ensure_ascii=False))
        raise SystemExit(1 if result['failed'] else 0)
    if command == 'review-export':
        return review_io.export(args.input, args.output)
    if command == 'review-import':
        return review_io.import_reviews(args.input, args.csv, args.output, args.approved)
    if command == 'secondary-export':
        return review_io.export_secondary(args.input, args.output)
    if command == 'secondary-import':
        return review_io.import_secondary(args.input, args.csv, args.output)
    if command == 'listen-export':
        return tts.export_listening(args.input, args.output)
    if command == 'listen-import':
        return tts.import_listening(args.input, args.csv)
    if command == 'tts-plan':
        return tts.plan(args.approved, args.output)
    if command == 'tts-synthesize':
        return tts.synthesize(args.manifest, args.audio_root, approved_path=args.approved)
    if command == 'tts-asr':
        return tts.asr(args.manifest, args.audio_root, args.model)
    if command == 'build':
        return build.build(args.approved, args.secondary, args.audio_manifest, args.audio_root,
                           args.output, args.version, expected_count=args.expected_count,
                           audio_base_url=args.audio_base_url, ranks=read_json(args.frequency_ranks) if args.frequency_ranks else None)
    if command == 'audit':
        return audit.run(args.package, args.output, args.previous)
    if command == 'dev-preview':
        return development.build_preview(args.input, args.output, args.identities)
    if command == 'dev-install':
        return development.install_preview(args.package, args.assets)
    if command == 'hs-source':
        return highschool.build_source(args.entries, args.output)
    if command == 'hs-draft':
        return highschool.draft(args.input, args.output)
    if command == 'hs-preview':
        return highschool.build_preview(args.input, args.output)
    if command == 'hs-release':
        return highschool.build_preview(args.input, args.output, release_version=args.version)
    if command.startswith('hs-review-'):
        from . import hs_review
        if command == 'hs-review-prepare':
            return hs_review.prepare_pending(args.pending) if args.pending else hs_review.prepare()
        if command == 'hs-review-merge':
            return hs_review.merge(args.dir) if args.dir else hs_review.merge()
        if command == 'hs-review-export':
            return hs_review.export_human(args.output) if args.output else hs_review.export_human()
        if command == 'hs-review-import':
            return hs_review.import_human(args.csv)
        if command == 'hs-review-web-export':
            return hs_review.export_web(args.output) if args.output else hs_review.export_web()
        if command == 'hs-review-web-import':
            return hs_review.import_web(args.json)
        return hs_review.status()
    if command == 'install':
        return build.install(args.package, args.assets)


if __name__ == '__main__':
    try:
        result = main()
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'content: {error}', file=sys.stderr)
        raise SystemExit(1)
