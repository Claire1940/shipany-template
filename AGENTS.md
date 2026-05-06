# Codex Agent Notes

## Direct Image Generation SOP

When a task needs new website image assets in this coding environment, use this flow by default:

1. Generate with the built-in `image_gen` tool first. Do not start from the ChatGPT web UI unless the built-in path is blocked.
2. The built-in tool saves original outputs under `/root/.codex/generated_images/<session-id>/`.
3. Inspect generated candidates before replacement. Use `view_image` on the saved files to verify style, composition, readability at target size, and whether the image matches the product/module it represents.
4. Keep the generated original in `/root/.codex/generated_images/...`. Do not delete it unless explicitly requested.
5. Copy the selected image into the project path that actually needs replacement, for example:
   - `public/imgs/features/...`
   - `public/imgs/avatars/...`
   - `public/imgs/bg/...`
6. If the project asset needs a specific size or format, convert after generation:
   - avatars: center-crop and resize to the required square size
   - backgrounds: convert PNG to JPG only if the target path requires JPG
   - feature cards: preserve the intended composition and target dimensions used by the page
7. If the replaced asset is referenced through a cache-stable URL, bump the query string in the consuming component or config when needed so browser review reflects the new image immediately.
8. After replacement, verify in the running site, not just on disk:
   - open the relevant page in the browser
   - wait for the page to finish loading
   - take a screenshot and inspect for broken images, stale cache, awkward crops, or style mismatch
9. For project-bound assets, finish only after the final file is in the repo path and the browser view has been checked.

## Practical Rule

If `image_gen` can produce the asset, prefer:

`image_gen -> inspect saved file -> copy/convert into repo -> browser verify`

This is the default path for Codex image asset work in this project.
