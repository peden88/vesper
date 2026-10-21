# AIOMetadata primary integration — implementation contract

Branch: feature/aiometadata-primary

## Goal
Use a user-supplied AIOMetadata Stremio manifest URL as the primary source for movie/series catalogs and title metadata in Vesper's Media Hub. Preserve existing IPTV, Jellyfin/Emby, playback and personal data.

## Protocol
- GET the full configured manifest URL, including any configuration path; never strip credentials or tokens.
- Read catalogs in manifest order. Identify catalogs by (manifest URL, type, id).
- Fetch /catalog/{type}/{id}.json and supported extras, including skip, genre and search. URL-encode each path segment and extra value.
- Fetch /meta/{type}/{id}.json for title details; use the response meta object and videos for seasons/episodes.
- Respect declared resource types/idPrefixes and optional capabilities. Do not assume every manifest supports search or metadata.
- Preserve provider IDs exactly; do not coerce non-IMDb IDs to IMDb IDs.
- Do not log full configured URLs, which may contain credentials.
- Use timeouts, bounded concurrency, refresh and stale-cache fallback.
- Block untrusted manifest redirects to unsupported schemes. Validate HTTPS by default; allow HTTP only with explicit opt-in for private LAN deployments.

## Passes
1. Audit existing Media Hub source models, persistence, network clients, UI routes and metadata resolution. Document exact integration points.
2. Add manifest-backed provider with validation, catalog enumeration, pagination and search.
3. Wire primary metadata resolution and episode mapping into Media Hub and title details, preserving fallback and playback.
4. Add settings, refresh controls, error states, automated tests and Android CI build.

## Acceptance tests
- Configured manifest catalogs appear in original order after restart.
- Movie/series/anime metadata and episode IDs survive navigation and playback handoff.
- Search only calls declared search catalogs.
- Removing or changing the manifest invalidates its cached data without deleting user progress.
- A temporary AIOMetadata outage does not break IPTV or crash the Media Hub.
- Existing Jellyfin/Emby and IPTV features remain functional.

Status: Planning contract only. No application source files changed yet.
