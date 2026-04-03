# Supported Marketplaces

Current marketplace ids in `Reseller.Marketplaces`:

- `ebay`
- `depop`
- `poshmark`
- `mercari`
- `facebook_marketplace`
- `offerup`
- `whatnot`
- `grailed`
- `therealreal`
- `vestiaire_collective`
- `thredup`
- `etsy`

Default selected marketplaces for new users:

- `ebay`
- `depop`
- `poshmark`

Notes:

- marketplace labels are defined in `lib/reseller/marketplaces.ex`
- seller-specific selection is stored on `users.selected_marketplaces`
- generated marketplace copy is stored in `marketplace_listings`
- seller-managed live URLs are stored in `marketplace_listings.external_url`
