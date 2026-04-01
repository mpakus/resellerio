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
            Effective date: June 1, 2025 · Last updated: June 1, 2025
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
            Product images you upload are stored on Amazon S3 (AWS) infrastructure in the United States and may be served via Bunny CDN. Original images are never overwritten. Processed variants (background-removed, lifestyle-generated) are stored alongside originals.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.4 Usage and Technical Data</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            We collect standard server logs including IP addresses, browser type, operating system, referring URLs, and pages visited. This data is used for security, debugging, and improving the Service.
          </p>

          <h3 class="mt-6 text-lg font-semibold">1.5 API Tokens</h3>
          <p class="mt-2 text-base leading-7 text-base-content/80">
            If you use our API, we issue bearer tokens that are hashed before storage. We log API requests for security and abuse prevention purposes.
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
            We share data with third-party providers only as necessary to operate the Service. All providers listed below are located in or process data in the United States:
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
                  <td class="px-4 py-3">Amazon S3 (AWS)</td>
                  <td class="px-4 py-3">Object storage for images and export archives</td>
                  <td class="px-4 py-3">Product images, ZIP export files</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Bunny CDN</td>
                  <td class="px-4 py-3">Content delivery for public storefront images</td>
                  <td class="px-4 py-3">Processed product images</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">GitHub</td>
                  <td class="px-4 py-3">Source code hosting and CI/CD</td>
                  <td class="px-4 py-3">No user data</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">4. Data Retention</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We retain your data for as long as your account is active. Export files expire after a configurable retention period (default 30 days). You may request deletion of your account and associated data at any time by contacting us at privacy@resellerio.com.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">5. Data Security</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            All data is transmitted over TLS. Passwords and API tokens are hashed using industry-standard algorithms before storage. We apply least-privilege access controls to our infrastructure. Despite these measures, no system is completely secure; you use the Service at your own risk.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">6. Your Rights</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            Depending on your jurisdiction, you may have the right to access, correct, export, or delete your personal data. To exercise any of these rights, contact us at privacy@resellerio.com. We will respond within 30 days.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">7. Cookies</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            We use session cookies to keep you signed in and CSRF tokens to protect against cross-site request forgery. We do not use third-party advertising or tracking cookies.
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
