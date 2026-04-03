defmodule ResellerWeb.PrivacyLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: ResellerWeb.PageTitle.build("Privacy Policy", "Legal"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
        <div class="prose prose-base max-w-none">
          <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Legal</p>
          <h1 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em]">
            Privacy Policy
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            Effective date: June 1, 2025 · Last updated: April 3, 2026
          </p>

          <p class="mt-8 text-base leading-7 text-base-content/80">
            ResellerIO ("we", "us", or "our") operates the ResellerIO platform, including the web application at resellerio.com and any associated mobile applications or APIs (collectively, the "Service"). This Privacy Policy explains what information we collect, how we use it, and your rights regarding that information.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">1. Information We Collect</h2>

          <h3 class="mt-6 text-lg font-semibold">1.1 Account Information</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            When you create an account we collect your email address and a hashed password. We do not store plaintext passwords. You may optionally provide additional profile details.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.2 Product and Inventory Data</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            We store the product records you create, including titles, descriptions, prices, images, and any metadata you enter. This data is associated with your account and used to provide the Service.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.3 Images and Media</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            Product images and archives you upload are stored using ResellerIO's configured Tigris-compatible object storage infrastructure. Public storefront media may be served from a configured public media URL or CDN. Original images are not overwritten. Processed variants are stored as separate records alongside originals.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.4 Usage and Technical Data</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            We collect standard server logs and operational metadata such as IP addresses, browser type, operating system, referring URLs, pages visited, API token usage timestamps, and public inquiry metadata. This data is used for security, abuse prevention, debugging, and service operations.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.5 API Tokens</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            If you use our API, we issue bearer tokens that are hashed before storage. We also store limited token metadata such as expiry, device name if supplied, and last-used timestamps.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">2. How We Use Your Information</h2>
          <ul class="mt-4 list-disc pl-6 space-y-2 text-base leading-7 text-base-content/80">
            <li>To create and manage your account and deliver the Service.</li>
            <li>
              To process your product images through AI pipelines (background removal, lifestyle generation, description drafting, pricing research).
            </li>
            <li>To generate marketplace-specific listing copy.</li>
            <li>To send transactional emails such as export-ready notifications.</li>
            <li>To maintain security, prevent abuse, and debug issues.</li>
            <li>To comply with legal obligations.</li>
          </ul>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">
            3. Third-Party Service Providers
          </h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We share data with third-party providers only as necessary to operate the Service. The categories below reflect the current service architecture and may change as our infrastructure evolves:
          </p>
          <div class="mt-4 overflow-hidden rounded-2xl border border-base-300">
            <table class="w-full text-sm">
              <thead class="bg-base-200/60">
                <tr>
                  <th class="px-4 py-3 text-left font-semibold">Provider</th>
                  <th class="px-4 py-3 text-left font-semibold">Purpose</th>
                  <th class="px-4 py-3 text-left font-semibold">Data Shared</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <tr>
                  <td class="px-4 py-3">Google Gemini API</td>
                  <td class="px-4 py-3">
                    AI description drafting, recognition, and pricing research
                  </td>
                  <td class="px-4 py-3">Product images, titles, category metadata</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">SerpAPI</td>
                  <td class="px-4 py-3">Sold-listing price research via search index</td>
                  <td class="px-4 py-3">Product title, brand, category, condition</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Photoroom API</td>
                  <td class="px-4 py-3">Background removal and image cleanup</td>
                  <td class="px-4 py-3">Product images</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Tigris-compatible object storage provider</td>
                  <td class="px-4 py-3">
                    Object storage for product media and import/export archives
                  </td>
                  <td class="px-4 py-3">Product images, storefront assets, ZIP archives</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Public media delivery / CDN provider</td>
                  <td class="px-4 py-3">Delivery of public storefront media when configured</td>
                  <td class="px-4 py-3">Public storefront images and branding assets</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">LemonSqueezy</td>
                  <td class="px-4 py-3">Subscription billing, checkout, and webhook events</td>
                  <td class="px-4 py-3">Account email, billing, and subscription identifiers</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">4. Data Retention</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We retain your data for as long as your account is active, subject to any legally required retention periods. Export files expire after a configurable retention period (currently seven days by default). You may request deletion of your account and associated data at any time by contacting us at privacy@resellerio.com.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">5. Data Security</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We use TLS for data in transit. Passwords are hashed with PBKDF2-SHA256 before storage and API bearer tokens are hashed before persistence. Browser sessions use HttpOnly cookies with SameSite protections and Secure cookies in production. The application also applies origin allowlists for browser API access, HMAC verification for billing webhooks, signed object-storage operations, inquiry rate limits, and archive validation checks for imports. Despite these measures, no system is completely secure.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">6. Your Rights</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            Depending on your jurisdiction, you may have the right to access, correct, export, or delete your personal data. To exercise any of these rights, contact us at privacy@resellerio.com. We will respond within 30 days.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">7. Cookies</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We use first-party session cookies to keep you signed in and CSRF protections to defend against cross-site request forgery. Session cookies are intended to be HttpOnly, SameSite-protected, and Secure in production. We do not use third-party advertising cookies.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">8. Children's Privacy</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            The Service is not directed to children under 13. We do not knowingly collect personal information from children under 13. If you believe we have inadvertently collected such information, please contact us immediately.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">9. Changes to This Policy</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We may update this Privacy Policy from time to time. We will notify registered users by email for material changes. Continued use of the Service after the effective date constitutes acceptance of the updated policy.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">10. Contact</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            For privacy questions or requests:
            <a href="mailto:privacy@resellerio.com" class="text-primary underline">
              privacy@resellerio.com
            </a>
          </p>

          <div class="mt-12 flex gap-4">
            <.link navigate={~p"/"} class="btn btn-ghost rounded-full">← Back to home</.link>
            <.link navigate={~p"/dpa"} class="btn btn-outline rounded-full">
              Data Processing Addendum →
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
