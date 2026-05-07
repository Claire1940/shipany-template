import { getTranslations } from 'next-intl/server';

import { Empty } from '@/shared/blocks/common';

export default async function EditApiKeyPage() {
  const t = await getTranslations('settings.apikeys');

  return <Empty message={t('list.unavailable_message')} />;
}
