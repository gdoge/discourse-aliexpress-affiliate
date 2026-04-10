# discourse-aliexpress-affiliate

A Discourse plugin that automatically converts AliExpress product URLs into affiliate links using the [AliExpress Portals Affiliate API](https://portals.aliexpress.com).

## How it works

Whenever a post is saved and cooked, the plugin scans the rendered HTML for any AliExpress URLs (aliexpress.com, aliexpress.us, aliexpress.ru). For each URL found it calls the AliExpress Affiliate API to obtain a tracked promotional link, then replaces the original URL in-place — both inside `<a href>` attributes and in plain text.

## Installation

Add the following line to your Discourse `app.yml` under the `hooks > after_code` section:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/YOUR_USERNAME/discourse-aliexpress-affiliate.git
```

Then rebuild your container:

```bash
./launcher rebuild app
```

## Configuration

Once installed, the plugin adds one site setting under **Admin → Settings → Plugins**:

| Setting | Default | Description |
|---|---|---|
| `aliexpress_affiliate_enabled` | `true` | Master switch for the plugin |

## Credentials

API credentials are hard-coded in `lib/aliexpress_affiliate_plugin/affiliate_link_converter.rb`. For production use it is recommended to move `APP_KEY`, `APP_SECRET`, and `TRACKING_ID` to Discourse site settings or environment variables so they can be rotated without a redeploy.

## Signing algorithm

The AliExpress API uses HMAC-SHA256:

1. Sort all request parameters alphabetically by key.
2. Concatenate as `key1value1key2value2…` (no delimiters).
3. Prepend and append the App Secret: `SECRET + concat + SECRET`.
4. Compute `HMAC-SHA256(key: APP_SECRET, data: above string)` and upper-case the hex result.

## License

MIT
