/// Public free localization releases.
const String githubFreeLatestReleaseUrl =
    'https://api.github.com/repos/strixcyron/SOLIDLEAF-TEAM/releases/latest';

/// Fallback for the public repo when it publishes under the named `update`
/// tag instead of a GitHub "latest" release (mirrors the auth backend logic).
const String githubFreeTagReleaseUrl =
    'https://api.github.com/repos/strixcyron/SOLIDLEAF-TEAM/releases/tags/update';

/// Private premium localization + texture releases.
const String githubPremiumLatestReleaseUrl =
    'https://api.github.com/repos/FrauxHD/PREMIUM/releases/latest';

/// Fallback for the premium repo: it ships its release under the named
/// `update` tag, so `/releases/latest` can 404 while this returns 200. The
/// auth backend already relies on this same fallback.
const String githubPremiumTagReleaseUrl =
    'https://api.github.com/repos/FrauxHD/PREMIUM/releases/tags/update';

const String shizukuChannel = 'com.example.re_1999_solidleaf/shizuku';
// Скачивание Shizuku (последний релиз) и официальный гайд по настройке.
const String shizukuDownloadUrl =
    'https://github.com/RikkaApps/Shizuku/releases/latest';
const String shizukuGuideUrl = 'https://shizuku.rikka.app/guide/setup/';
const String boostyUrl = 'https://boosty.to/strix.cyron/donate';
// Public community group — joining this is enough to log in with "basic"
// (text-only) access.
const String telegramUrl = 'https://t.me/reverse1999_solidleaf';
// Private premium group (invite link) — members get "premium" access,
// unlocking the "Графика и текстуры" card. Kept separate from [telegramUrl]
// since the two grant different access tiers on the backend.
const String premiumChannelUrl =
    'https://boosty.to/strix.cyron/purchase/3761019?ssource=DIRECT&share=subscription_link';
