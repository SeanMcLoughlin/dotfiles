export const meta = {
  name: 'code-review-parallel',
  description: 'Review a changelist with all personas in parallel, verify the findings, then apply fixes in priority order',
  phases: [
    { title: 'Find', detail: 'every persona reads every shard at once, read-only' },
    { title: 'Verify', detail: 'independent agents try to refute the costly findings' },
    { title: 'Apply', detail: 'one fixer per persona, in priority order, serial' },
  ],
}

const branch = args.branch
const workdir = args.workdir
const shards = args.shards
const enabled = args.personas

/**
 * Every persona, in the order their fixes must be applied. The order is
 * load-bearing: names settle before structure, structure before behaviour,
 * behaviour before tests, and prose last because it describes the rest.
 */
const PERSONAS = [
  { key: 'naming-critic', title: 'Naming Critic', fixes: true, verify: false },
  { key: 'architect', title: 'Architect', fixes: true, verify: true },
  { key: 'bug-hunter', title: 'Bug Hunter', fixes: true, verify: true },
  { key: 'test-reviewer', title: 'Test Reviewer', fixes: true, verify: false },
  { key: 'doc-nitpicker', title: 'Doc Nitpicker', fixes: true, verify: false, model: 'sonnet', effort: 'low' },
  { key: 'questioner', title: 'Questioner', fixes: false, verify: false },
  { key: 'perf-reviewer', title: 'Performance Reviewer', fixes: false, verify: true },
  { key: 'magic-numbers', title: 'Magic Numbers', fixes: true, verify: false, model: 'sonnet', effort: 'low' },
]

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'severity', 'summary', 'suggested_fix'],
        additionalProperties: false,
        properties: {
          file: { type: 'string', description: 'repo-relative path' },
          line: { type: 'integer', description: '1-indexed line in the current file' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          summary: { type: 'string', description: 'one sentence: what is wrong' },
          evidence: { type: 'string', description: 'the code or diff hunk that shows it' },
          suggested_fix: { type: 'string', description: 'concretely what to change' },
        },
      },
    },
    notes: { type: 'string', description: 'anything the fixer must know that is not a finding' },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reason'],
  additionalProperties: false,
  properties: {
    refuted: { type: 'boolean', description: 'true if the finding is wrong, already handled, or not worth the change' },
    reason: { type: 'string' },
  },
}

const APPLY_SCHEMA = {
  type: 'object',
  required: ['applied', 'skipped', 'committed'],
  additionalProperties: false,
  properties: {
    applied: { type: 'array', items: { type: 'string' }, description: 'one line per fix made' },
    skipped: { type: 'array', items: { type: 'string' }, description: 'one line per finding not fixed, with the reason' },
    flagged: { type: 'array', items: { type: 'string' }, description: 'needs a human decision' },
    committed: { type: 'boolean' },
    escalation: { type: 'string', description: 'set only if you stopped early; say why' },
  },
}

const preamble = `You are reviewing branch ${branch} in the repository at ${workdir}.
cd to ${workdir} before anything else. The branch is already fetched and rebased
against origin/main, so do not fetch, rebase, or switch branches.`

function findPrompt(persona, shard, shardIndex) {
  return `${preamble}

Read ~/.skills/${persona.key}/SKILL.md. Use it ONLY for its judgment criteria --
the list of things that persona looks for. Ignore its process: skip its branch
setup, skip its fix loop, skip its commit step, and skip its report format.

You are a FINDER, not a fixer. This is the hard rule of this run:
- Make NO edits. Do not write, move, or delete any file.
- Run NO git command that changes state. Reading (git diff, git log, git show) is fine.
- Do not commit.

Review exactly these ${shard.length} file(s), and nothing else:
${shard.map((f) => `  ${f}`).join('\n')}

Start from the diff, scoped to your files:
  git diff origin/main...HEAD -- ${shard.map((f) => `'${f}'`).join(' ')}
Then read each file's current full contents, because the diff hides context.

Report every problem you find that your persona would have fixed. Judge only
what this changelist introduces or worsens; do not audit pre-existing code.
Give a precise file and line, and a suggested_fix concrete enough that another
agent can apply it without repeating your analysis.

Be strict about relevance. A finding another persona owns is not yours: leave
naming to the naming critic, prose to the doc nitpicker, and so on.
Report an empty findings array if the files are clean. An empty array is a
perfectly good result -- do not invent work.
${shards.length > 1 ? `\nYou are shard ${shardIndex + 1} of ${shards.length}. Other agents cover the rest of the diff in parallel, so ignore files outside your list even if they look related.` : ''}`
}

function verifyPrompt(finding, persona) {
  return `${preamble}

Your job is to REFUTE a code review finding. Assume it is wrong until the code
proves otherwise. A finding that survives you gets acted on, so a false
positive here costs real work.

Finding, from the ${persona.title} persona:
  file: ${finding.file}:${finding.line}
  severity: ${finding.severity}
  claim: ${finding.summary}
  evidence given: ${finding.evidence || '(none given)'}
  proposed fix: ${finding.suggested_fix}

Read the file and whatever else you need. Make no edits.

Set refuted=true if any of these hold:
- The claim misreads the code, or the problem is already handled elsewhere.
- The code is pre-existing and this changelist did not introduce or worsen it.
- The proposed fix would not improve the code, or would break something.
- The finding is too vague to act on.

If you cannot decide, set refuted=true. Uncertainty is a refusal here.`
}

function applyPrompt(persona, findings) {
  const extra =
    persona.key === 'bug-hunter'
      ? `\nYour persona's core rule still applies: prove each bug with a failing test
BEFORE you fix it, then confirm the test passes after. Commit test and fix
together. If a bug cannot be given a failing test, say so in skipped rather
than fixing it blind.`
      : `\nAfter your fixes, run the project's build or lint command if there is a
standard one, so you do not leave the tree broken.`

  return `${preamble}

Read ~/.skills/${persona.key}/SKILL.md for how your persona works and what it
values. Follow its fix and commit steps. Skip its branch setup, and skip its
own find loop -- the finding work is already done and verified for you below.

${findings.length} verified finding(s) to act on:
${JSON.stringify(findings, null, 2)}

Work through them in order. For each one:
1. Read the code around it. The finding was made against this same commit, but
   an earlier persona may have already changed that area in this same review.
   If a finding no longer applies, put it in skipped and move on.
2. Apply the fix if it is genuinely an improvement. Keep it minimal and
   contained; do not refactor adjacent code that is not in the changelist.
3. If it needs a human decision, put it in flagged and do not guess.

You may fix a closely related problem you notice while editing, but do not
start a fresh hunt of your own -- that is what made this review slow before.
${extra}

Commit your changes before you exit, with a message your persona would write.
Set committed=true only if you actually made a commit.`
}

// ---------------------------------------------------------------- find

phase('Find')

const active = PERSONAS.filter((p) => enabled.includes(p.key))
const jobs = []
for (const persona of active) {
  for (let i = 0; i < shards.length; i++) {
    jobs.push({ persona, shard: shards[i], shardIndex: i })
  }
}

log(`${active.length} personas x ${shards.length} shard(s) = ${jobs.length} finders, all read-only`)

const found = await parallel(
  jobs.map((job) => () =>
    agent(findPrompt(job.persona, job.shard, job.shardIndex), {
      label: `find:${job.persona.key}${shards.length > 1 ? `:s${job.shardIndex + 1}` : ''}`,
      phase: 'Find',
      schema: FINDINGS_SCHEMA,
      model: job.persona.model,
      effort: job.persona.effort,
    }).then((r) => ({ job, result: r }))
  )
)

const byPersona = {}
const finderNotes = {}
for (const p of active) {
  byPersona[p.key] = []
  finderNotes[p.key] = []
}

let deadFinders = 0
for (const entry of found) {
  if (!entry || !entry.result) {
    deadFinders++
    continue
  }
  const key = entry.job.persona.key
  for (const f of entry.result.findings || []) {
    byPersona[key].push(f)
  }
  if (entry.result.notes) finderNotes[key].push(entry.result.notes)
}
if (deadFinders) log(`WARNING: ${deadFinders} of ${jobs.length} finders returned nothing -- their files went unreviewed`)

/** Two personas flagging one line is one finding. Keep the more severe wording. */
const RANK = { high: 3, medium: 2, low: 1 }
for (const p of active) {
  const seen = new Map()
  for (const f of byPersona[p.key]) {
    const k = `${f.file}:${f.line}:${(f.summary || '').slice(0, 40).toLowerCase()}`
    const prev = seen.get(k)
    if (!prev || RANK[f.severity] > RANK[prev.severity]) seen.set(k, f)
  }
  byPersona[p.key] = [...seen.values()].sort((a, b) => RANK[b.severity] - RANK[a.severity])
}

const totalFound = active.reduce((n, p) => n + byPersona[p.key].length, 0)
log(`${totalFound} findings after dedup: ${active.map((p) => `${p.key}=${byPersona[p.key].length}`).join(' ')}`)

// ---------------------------------------------------------------- verify

phase('Verify')

const VERIFY_CAP = 60
const toVerify = []
for (const p of active.filter((p) => p.verify)) {
  for (const f of byPersona[p.key]) toVerify.push({ persona: p, finding: f })
}

let verifySkipped = []
if (toVerify.length > VERIFY_CAP) {
  const kept = toVerify.filter((v) => v.finding.severity !== 'low')
  verifySkipped = toVerify.filter((v) => v.finding.severity === 'low')
  log(`${toVerify.length} findings exceed the ${VERIFY_CAP} verify cap; ${verifySkipped.length} low-severity findings go through UNVERIFIED`)
  toVerify.length = 0
  toVerify.push(...kept)
}

const verdicts = await parallel(
  toVerify.map((v) => () =>
    agent(verifyPrompt(v.finding, v.persona), {
      label: `verify:${v.finding.file.split('/').pop()}:${v.finding.line}`,
      phase: 'Verify',
      schema: VERDICT_SCHEMA,
    }).then((r) => ({ ...v, verdict: r }))
  )
)

const refuted = []
const survived = new Set()
/** A verifier that died proves nothing, so its finding is kept, not discarded. */
const unjudged = new Set()
for (let i = 0; i < verdicts.length; i++) {
  const v = verdicts[i]
  if (!v || !v.verdict) {
    unjudged.add(toVerify[i].finding)
    continue
  }
  if (v.verdict.refuted) {
    refuted.push({ persona: v.persona.title, finding: v.finding, reason: v.verdict.reason })
  } else {
    survived.add(v.finding)
  }
}

for (const p of active.filter((p) => p.verify)) {
  const capped = new Set(verifySkipped.filter((v) => v.persona.key === p.key).map((v) => v.finding))
  byPersona[p.key] = byPersona[p.key].filter((f) => survived.has(f) || capped.has(f) || unjudged.has(f))
}

if (refuted.length) log(`${refuted.length} findings refuted and dropped`)
if (unjudged.size) log(`WARNING: ${unjudged.size} verifiers died; their findings go through UNVERIFIED`)

// ---------------------------------------------------------------- apply

phase('Apply')

const reports = {}
for (const p of active) {
  const findings = byPersona[p.key]
  if (!p.fixes) {
    reports[p.key] = { reportOnly: true, findings, notes: finderNotes[p.key] }
    continue
  }
  if (!findings.length) {
    reports[p.key] = { clean: true }
    continue
  }
  // Serial on purpose: these agents edit and commit in one shared worktree.
  log(`applying ${findings.length} ${p.key} finding(s)`)
  const outcome = await agent(applyPrompt(p, findings), {
    label: `apply:${p.key}`,
    phase: 'Apply',
    schema: APPLY_SCHEMA,
    model: p.model,
  })
  reports[p.key] = outcome || { escalation: 'the fixer agent died; nothing was applied', applied: [], skipped: [], committed: false }
}

return {
  branch,
  shardCount: shards.length,
  finderCount: jobs.length,
  deadFinders,
  totalFound,
  refuted,
  unverifiedCount: verifySkipped.length + unjudged.size,
  order: active.map((p) => p.key),
  titles: Object.fromEntries(active.map((p) => [p.key, p.title])),
  reports,
}
