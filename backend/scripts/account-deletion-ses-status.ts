/** Reads SES readiness for foloo.io without sending or modifying anything. */

import {
  GetAccountCommand,
  GetEmailIdentityCommand,
  SESv2Client,
} from "@aws-sdk/client-sesv2";

const region = process.env.AWS_REGION ?? "us-east-1";
const identity = process.env.ACCOUNT_DELETION_SES_DOMAIN ?? "foloo.io";
const client = new SESv2Client({ region });

const account = await client.send(new GetAccountCommand({}));
let identityStatus: Record<string, boolean | string> = { exists: false };
try {
  const emailIdentity = await client.send(
    new GetEmailIdentityCommand({ EmailIdentity: identity }),
  );
  identityStatus = {
    exists: true,
    verifiedForSending: emailIdentity.VerifiedForSendingStatus ?? false,
    dkimStatus: emailIdentity.DkimAttributes?.Status ?? "NOT_STARTED",
    dkimSigningEnabled: emailIdentity.DkimAttributes?.SigningEnabled ?? false,
  };
} catch (error) {
  if ((error as { name?: string }).name !== "NotFoundException") throw error;
}

process.stdout.write(
  `${JSON.stringify(
    {
      region,
      identity,
      account: {
        productionAccessEnabled: account.ProductionAccessEnabled ?? false,
        sendingEnabled: account.SendingEnabled ?? false,
        enforcementStatus: account.EnforcementStatus ?? "UNKNOWN",
      },
      identityStatus,
    },
    null,
    2,
  )}\n`,
);
