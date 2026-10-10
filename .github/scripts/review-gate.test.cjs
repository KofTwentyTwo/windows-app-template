// Copyright (c) 2026 James Maes (KofTwentyTwo)
// SPDX-License-Identifier: MIT

"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { evaluateReviewRecord, run } = require("./review-gate.cjs");
const sha = "a".repeat(40);

/** A maintainer-recorded review of the current commit. */
function record(overrides = {})
{
   return {
      id: 1, updated_at: "2026-10-10T12:00:00Z", user: { login: "@KofTwentyTwo".slice(1), type: "User" },
      body: `<!-- k22-automated-review:${sha} -->\nTool: Codex\nFindings: none\n`
         + "Summary: Reviewed input validation, workflow permissions, and regression coverage.\n"
         + "Maintainer acknowledgement: I read the review and resolved or answered every finding.",
      ...overrides,
   };
}

test("accepts a current complete record from the maintainer", () =>
{
   assert.equal(evaluateReviewRecord([record()], sha, "@KofTwentyTwo".slice(1)).passed, true);
});

test("rejects stale commits, outsiders, bots, missing acknowledgement and unresolved findings", () =>
{
   const cases = [
      [],
      [record({ body: record().body.replace(sha, "b".repeat(40)) })],
      [record({ user: { login: "contributor", type: "User" } })],
      [record({ user: { login: "@KofTwentyTwo".slice(1), type: "Bot" } })],
      [record({ body: record().body.replace("Maintainer acknowledgement:", "Pending acknowledgement:") })],
      [record({ body: record().body.replace("Findings: none", "Findings: unresolved") })],
      [record({ body: record().body.replace("Summary:", "No summary:") })],
      [record({ body: record().body + "\nFindings: unresolved" })],
      [record({ body: record().body + "\nTool: Unknown" })],
      [record({ body: record().body.replace("Tool: Codex", "Tool: Unknown") })],
      [record({ body: record().body.replace("Summary: Reviewed input validation, workflow permissions, and regression coverage.", "Summary: Too short.") })],
   ];
   for(const comments of cases)
   {
      assert.equal(evaluateReviewRecord(comments, sha, "@KofTwentyTwo".slice(1)).passed, false);
   }
});

test("a newer unresolved record overrides an older passing record", () =>
{
   const latest = record({ id: 2, updated_at: "2026-10-10T13:00:00Z", body: record().body.replace("Findings: none", "Findings: unresolved") });
   assert.equal(evaluateReviewRecord([record(), latest], sha, "@KofTwentyTwo".slice(1)).passed, false);
});

test("an edited record supersedes the previous review", () =>
{
   const updated = record({ updated_at: "2026-10-10T14:00:00Z", body: record().body.replace("Findings: none", "Findings: resolved") });
   const previous = record({ id: 2, updated_at: "2026-10-10T13:00:00Z", body: record().body.replace("Findings: none", "Findings: unresolved") });
   assert.equal(evaluateReviewRecord([previous, updated], sha, "@KofTwentyTwo".slice(1)).passed, true);
});

test("publishes to the live PR head and paginates review comments", async () =>
{
   const writes = [];
   const github = {
      rest: {
         pulls: { get: async () => ({ data: { state: "open", base: { ref: "main" }, head: { sha } } }) },
         issues: { listComments: "comments" },
         checks: {
            create: async input =>
            {
               writes.push(input); return { data: { id: 9 } };
            },
            update: async input =>
            {
               writes.push(input);
            },
         },
      },
      paginate: async (method, input) =>
      {
         assert.equal(method, "comments");
         assert.equal(input.issue_number, 7);
         return [record()];
      },
   };
   await run({ github, context: { repo: { owner: "@KofTwentyTwo".slice(1), repo: "AppKit" }, payload: { issue: { number: 7 } } },
      core: { setFailed: assert.fail, info: () =>
      {} } });
   assert.equal(writes[0].head_sha, sha);
   assert.equal(writes[0].conclusion, "failure");
   assert.equal(writes[1].check_run_id, 9);
   assert.equal(writes[1].conclusion, "success");
});

test("an API failure leaves the current head check failed", async () =>
{
   const writes = [];
   const github = {
      rest: {
         pulls: { get: async () => ({ data: { state: "open", base: { ref: "main" }, head: { sha } } }) },
         issues: { listComments: "comments" },
         checks: {
            create: async input =>
            {
               writes.push(input); return { data: { id: 9 } };
            },
            update: async input =>
            {
               writes.push(input);
            },
         },
      },
      paginate: async () =>
      {
         throw new Error("API unavailable");
      },
   };
   await assert.rejects(run({ github,
      context: { repo: { owner: "@KofTwentyTwo".slice(1), repo: "AppKit" }, payload: { issue: { number: 7 } } },
      core: { setFailed: assert.fail, info: () =>
      {} },
   }), /API unavailable/);
   assert.equal(writes.length, 1);
   assert.equal(writes[0].head_sha, sha);
   assert.equal(writes[0].conclusion, "failure");
});

test("ignores closed PRs and PRs targeting another branch", async () =>
{
   for(const pull of [{ state: "closed", base: { ref: "main" } }, { state: "open", base: { ref: "other" } }])
   {
      let ignored = false;
      await run({
         github: { rest: { pulls: { get: async () => ({ data: pull }) } } },
         context: { repo: { owner: "@KofTwentyTwo".slice(1), repo: "AppKit" }, payload: { issue: { number: 7 } } },
         core: { info: () =>
         {
            ignored = true;
         }, setFailed: assert.fail },
      });
      assert.equal(ignored, true);
   }
});
