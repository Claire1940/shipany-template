export const AI_PROVIDER_FLAG_MAP = {
  openrouter: 'openrouter_enabled',
  kie: 'kie_enabled',
  replicate: 'replicate_enabled',
  fal: 'fal_enabled',
  gemini: 'gemini_enabled',
} as const;

export type AIProviderName = keyof typeof AI_PROVIDER_FLAG_MAP;

export function isTruthyConfigValue(value?: string | null) {
  return value === 'true' || value === '1';
}

export function getEnabledAIProviders(configs: Record<string, string>) {
  const enabledProviders = new Set<AIProviderName>();

  for (const [provider, flag] of Object.entries(AI_PROVIDER_FLAG_MAP) as [
    AIProviderName,
    string,
  ][]) {
    if (isTruthyConfigValue(configs[flag])) {
      enabledProviders.add(provider);
    }
  }

  return enabledProviders;
}

export function hasLoadedAIProviderFlags(configs: Record<string, string>) {
  return Object.values(AI_PROVIDER_FLAG_MAP).some((flag) => flag in configs);
}
