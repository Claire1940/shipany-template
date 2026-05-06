import { Configs } from '@/shared/models/config';

type CreemModerationDecision = 'allow' | 'flag' | 'deny';

interface CreemModerationResponse {
  decision?: CreemModerationDecision;
}

export async function moderateCreemPrompt({
  prompt,
  externalId,
  configs,
}: {
  prompt: string;
  externalId: string;
  configs: Configs;
}) {
  const apiKey = configs.creem_api_key;
  const environment =
    configs.creem_environment === 'production' ? 'production' : 'sandbox';
  const baseUrl =
    environment === 'production'
      ? 'https://api.creem.io'
      : 'https://test-api.creem.io';

  if (!apiKey) {
    throw new Error('image and video moderation is not configured');
  }

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/moderation/prompt`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
      },
      body: JSON.stringify({
        prompt,
        external_id: externalId,
      }),
      signal: AbortSignal.timeout(5000),
    });
  } catch (error) {
    console.error('creem moderation request failed', error);
    throw new Error(
      'prompt screening is temporarily unavailable, please try again'
    );
  }

  if (!response.ok) {
    console.error('creem moderation http error', response.status);
    throw new Error(
      'prompt screening is temporarily unavailable, please try again'
    );
  }

  const result = (await response.json()) as CreemModerationResponse;
  if (result.decision === 'deny' || result.decision === 'flag') {
    throw new Error(
      'your prompt could not be processed because it violates our content policy'
    );
  }

  if (result.decision !== 'allow') {
    throw new Error(
      'prompt screening is temporarily unavailable, please try again'
    );
  }
}
