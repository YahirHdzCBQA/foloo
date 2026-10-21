/** Non-destructive AWS DEV smoke checks; never creates or confirms deletion. */

const baseUrl = process.env.FOLOO_API_BASE_URL;
const accessToken = process.env.FOLOO_QA_ACCESS_TOKEN;
if (!baseUrl || !accessToken) {
  throw new Error("FOLOO_API_BASE_URL and FOLOO_QA_ACCESS_TOKEN are required.");
}

const headers = { authorization: `Bearer ${accessToken}` };
for (const check of [
  { method: "GET", path: "/v1/account-deletion-requests/current" },
  {
    method: "POST",
    path: "/v1/account-deletion-reauthentication/verify",
  },
] as const) {
  const response = await fetch(new URL(check.path, baseUrl), {
    method: check.method,
    headers,
  });
  if (![200, 503].includes(response.status)) {
    throw new Error(
      `Safe Account Deletion smoke check failed (${response.status}).`,
    );
  }
}
console.info("Account Deletion non-destructive smoke checks passed.");
