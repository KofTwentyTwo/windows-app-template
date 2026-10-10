// Copyright (c) 2026 James Maes (KofTwentyTwo)
// SPDX-License-Identifier: MIT

"use strict";

const acknowledgement = "Maintainer acknowledgement: I read the review and resolved or answered every finding.";

/** Accepts only the latest maintainer-owned record for the current commit. */
function evaluateReviewRecord(comments, sha, maintainer)
{
   const marker = `<!-- k22-automated-review:${sha} -->`;
   const records = comments.filter(comment =>
      comment.user?.login === maintainer
      && comment.user?.type === "User"
      && typeof comment.body === "string"
      && comment.body.includes(marker));
   records.sort((left, right) =>
      String(right.updated_at).localeCompare(String(left.updated_at)) || right.id - left.id);
   const record = records[0];
   if(!record)
   {
      return { passed: false, reason: "No maintainer-owned automated review record exists for the current PR commit." };
   }
   const lines = record.body.split(/\r?\n/).map(line => line.trim());
   const field = name =>
   {
      const values = lines.filter(line => line.startsWith(`${name}:`));
      return values.length === 1 ? values[0].slice(name.length + 1).trim() : null;
   };
   const passed = lines.includes(marker)
      && ["Codex", "Claude", "Copilot"].includes(field("Tool"))
      && ["none", "resolved"].includes(field("Findings"))
      && (field("Summary")?.length ?? 0) >= 20
      && lines.includes(acknowledgement);
   return { passed, reason: passed ? "Current commit reviewed and acknowledged by the maintainer."
      : "The latest review record is incomplete or still has unresolved findings." };
}



/** Publishes a check on the PR head without ever fetching or executing its code. */
async function run({ github, context, core })
{
   const { owner, repo } = context.repo;
   const pullNumber = context.payload.pull_request?.number ?? context.payload.issue?.number;
   const { data: pull } = await github.rest.pulls.get({ owner, repo, pull_number: pullNumber });
   if(pull.state !== "open" || pull.base.ref !== "main")
   {
      core.info("Only open PRs targeting main require a review record.");
      return;
   }
   const sha = pull.head.sha;
   // Start failed: an API error must never leave an apparently successful gate.
   const { data: check } = await github.rest.checks.create({
      owner, repo, name: "review / automated", head_sha: sha,
      status: "completed", conclusion: "failure",
      output: { title: "Automated review required", summary: "Waiting for validation of the current commit review record." },
   });
   const comments = await github.paginate(github.rest.issues.listComments, {
      owner, repo, issue_number: pullNumber, per_page: 100,
   });
   const result = evaluateReviewRecord(comments, sha, "@KofTwentyTwo".slice(1));
   await github.rest.checks.update({
      owner, repo, check_run_id: check.id,
      status: "completed", conclusion: result.passed ? "success" : "failure",
      output: { title: result.passed ? "Automated review recorded" : "Automated review required", summary: result.reason },
   });
   if(!result.passed)
   {
      core.setFailed(result.reason);
   }
}

module.exports = { evaluateReviewRecord, run };
