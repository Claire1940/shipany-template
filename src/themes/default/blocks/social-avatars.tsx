import { Star } from 'lucide-react';

import { Avatar, AvatarFallback, AvatarImage } from '@/shared/components/ui/avatar';

const userImgUrls = [
  '/imgs/avatars/oneaihub-chat-avatar.png?v=20260506c',
  '/imgs/avatars/oneaihub-image-avatar.png?v=20260506c',
  '/imgs/avatars/oneaihub-music-avatar.png?v=20260506c',
  '/imgs/avatars/oneaihub-credits-avatar.png?v=20260506c',
  '/imgs/avatars/oneaihub-workflow-avatar.png?v=20260506c',
  '/imgs/avatars/oneaihub-admin-avatar.png?v=20260506c',
];

export function SocialAvatars({ tip }: { tip: string }) {
  return (
    <div className="mx-auto mt-8 flex w-fit flex-col items-center gap-2 sm:flex-row">
      <span className="mx-4 inline-flex items-center -space-x-2">
        {userImgUrls.map((url, index) => (
          <Avatar className="size-10 border" key={index}>
            <AvatarImage src={url} alt="OneAIHub creator avatar" />
            <AvatarFallback>{index + 1}</AvatarFallback>
          </Avatar>
        ))}
      </span>
      <div className="flex flex-col items-center gap-1 md:items-start">
        <div className="flex items-center gap-1">
          {Array.from({ length: 5 }).map((_, index) => (
            <Star
              key={index}
              className="size-4 fill-yellow-400 text-yellow-400"
            />
          ))}
        </div>
        <p className="text-muted-foreground text-left text-sm font-normal">
          {tip}
        </p>
      </div>
    </div>
  );
}
