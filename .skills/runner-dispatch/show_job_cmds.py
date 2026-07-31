#!/usr/bin/env python3
"""Print the resolved, env-expanded commands a pipeline's jobs run.
Usage: show_job_cmds.py <pipeline_id>
Needs: GITLAB_TOKEN with api scope (for ci-lint compile + pipeline variables).
"""
import json, os, re, subprocess, sys

PROJECT = "arch%2Fcallandor"
pid = sys.argv[1]

def glab_api(path):
    out = subprocess.check_output(["glab", "api", path], text=True)
    return json.loads(out)

# 1. jobs actually in this pipeline
jobs = [j["name"] for j in glab_api(f"projects/{PROJECT}/pipelines/{pid}/jobs?per_page=100")]

# 2. pipeline trigger variables (override job-level vars)
pipe_vars = {v["key"]: v["value"] for v in glab_api(f"projects/{PROJECT}/pipelines/{pid}/variables")}

# 3. merged/compiled CI config (extends + !reference + includes resolved)
import yaml  # provided via `uv run --with pyyaml`
merged = subprocess.check_output(["glab", "ci", "config", "compile"], text=True)
cfg = yaml.safe_load(merged)

def expand(line, env):
    # ${VAR} and $VAR; leave unknown vars untouched
    line = re.sub(r"\$\{(\w+)\}", lambda m: env.get(m.group(1), m.group(0)), line)
    line = re.sub(r"\$(\w+)", lambda m: env.get(m.group(1), m.group(0)), line)
    return line

for name in jobs:
    job = cfg.get(name, {}) or {}
    env = {**(job.get("variables") or {}), **pipe_vars}
    print(f"\n===== {name} =====")
    print("# variables in effect:")
    for k, v in env.items():
        print(f"#   {k}={v}")
    for section in ("before_script", "script", "after_script"):
        lines = job.get(section) or []
        if not lines:
            continue
        print(f"# --- {section} (env-expanded) ---")
        for raw in lines:
            for physical in raw.split("\n"):
                print(expand(physical, env))
