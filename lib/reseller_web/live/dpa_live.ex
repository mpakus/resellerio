defmodule ResellerWeb.DPALive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: ResellerWeb.PageTitle.build("Data Processing Addendum", "Legal"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
        <div class="prose prose-base max-w-none">
          <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Legal</p>
          <h1 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em]">
            Data Processing Addendum
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            Effective date: June 1, 2025 · Last updated: April 3, 2026
          </p>

          <p class="mt-8 text-base leading-7 text-base-content/80">
            This Data Processing Addendum ("DPA") forms part of the agreement between ResellerIO ("Processor") and the customer ("Controller") who uses the ResellerIO Service. It sets out the terms under which ResellerIO processes personal data on behalf of the Controller.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">1. Definitions</h2>
          <ul class="mt-4 list-disc pl-6 space-y-2 text-base leading-7 text-base-content/80">
            <li>
              <strong>Personal Data</strong>
              — any information relating to an identified or identifiable natural person processed under this DPA.
            </li>
            <li>
              <strong>Processing</strong>
              — any operation performed on Personal Data, including collection, storage, use, disclosure, and deletion.
            </li>
            <li>
              <strong>Sub-processor</strong>
              — any third party engaged by ResellerIO to process Personal Data.
            </li>
            <li>
              <strong>GDPR</strong>
              — the EU General Data Protection Regulation 2016/679 and any applicable national implementations.
            </li>
            <li>
              <strong>CCPA</strong>
              — the California Consumer Privacy Act (Cal. Civ. Code § 1798.100 et seq.) and the CPRA amendments.
            </li>
          </ul>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">2. Scope and Role</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            ResellerIO acts as a Processor with respect to Personal Data that the Controller submits to the Service. The Controller determines the purposes and means of processing. Each party agrees to comply with applicable data protection laws.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">3. Subject Matter of Processing</h2>
          <div class="mt-4 overflow-hidden rounded-2xl border border-base-300">
            <table class="w-full text-sm">
              <tbody class="divide-y divide-base-300">
                <tr>
                  <td class="px-4 py-3 font-semibold w-40">Nature</td>
                  <td class="px-4 py-3">
                    Storage, AI-assisted analysis, image processing, export generation, and delivery of the ResellerIO platform.
                  </td>
                </tr>
                <tr>
                  <td class="px-4 py-3 font-semibold">Purpose</td>
                  <td class="px-4 py-3">
                    Providing the features described in the Privacy Policy and any order documentation.
                  </td>
                </tr>
                <tr>
                  <td class="px-4 py-3 font-semibold">Duration</td>
                  <td class="px-4 py-3">
                    For the term of the customer's active subscription or account, plus any legally required retention period thereafter.
                  </td>
                </tr>
                <tr>
                  <td class="px-4 py-3 font-semibold">Data types</td>
                  <td class="px-4 py-3">
                    Email addresses, hashed passwords, API token metadata, product descriptions, product images, storefront content, marketplace copy, pricing data, public inquiry metadata, billing identifiers, and usage/security logs.
                  </td>
                </tr>
                <tr>
                  <td class="px-4 py-3 font-semibold">Data subjects</td>
                  <td class="px-4 py-3">
                    Users and customers of the Controller who interact with the ResellerIO platform.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">4. Processor Obligations</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">ResellerIO shall:</p>
          <ul class="mt-4 list-disc pl-6 space-y-2 text-base leading-7 text-base-content/80">
            <li>
              Process Personal Data only on documented instructions from the Controller, unless required to do so by applicable law.
            </li>
            <li>
              Ensure that persons authorised to process the Personal Data have committed to confidentiality.
            </li>
            <li>
              Implement appropriate technical and organisational security measures as described in Section 7.
            </li>
            <li>
              Assist the Controller in responding to Data Subject rights requests within 30 days.
            </li>
            <li>
              Notify the Controller without undue delay (and in any event within 72 hours) upon becoming aware of a Personal Data breach.
            </li>
            <li>
              Delete or return all Personal Data to the Controller upon termination of the Service, at the Controller's choice, unless retention is required by law.
            </li>
            <li>
              Make available all information necessary to demonstrate compliance with this DPA and allow audits conducted by the Controller or an authorised auditor.
            </li>
          </ul>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">5. Sub-processors</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            ResellerIO hereby notifies the Controller of the following approved sub-processors and processing categories used to operate the Service.
          </p>
          <div class="mt-4 overflow-hidden rounded-2xl border border-base-300">
            <table class="w-full text-sm">
              <thead class="bg-base-200/60">
                <tr>
                  <th class="px-4 py-3 text-left font-semibold">Sub-processor</th>
                  <th class="px-4 py-3 text-left font-semibold">Purpose</th>
                  <th class="px-4 py-3 text-left font-semibold">Location</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <tr>
                  <td class="px-4 py-3">Google LLC (Gemini API)</td>
                  <td class="px-4 py-3">
                    AI image analysis, description generation, pricing research
                  </td>
                  <td class="px-4 py-3">USA</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">SerpAPI, LLC</td>
                  <td class="px-4 py-3">Market price research via search index queries</td>
                  <td class="px-4 py-3">USA</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Photoroom SAS</td>
                  <td class="px-4 py-3">Background removal and image cleanup</td>
                  <td class="px-4 py-3">As configured by provider</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Tigris-compatible object storage provider</td>
                  <td class="px-4 py-3">
                    Object storage for product media and import/export archives
                  </td>
                  <td class="px-4 py-3">As configured by ResellerIO</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">Public media delivery / CDN provider</td>
                  <td class="px-4 py-3">
                    Public delivery of storefront assets and images when configured
                  </td>
                  <td class="px-4 py-3">As configured by ResellerIO</td>
                </tr>
                <tr>
                  <td class="px-4 py-3">LemonSqueezy</td>
                  <td class="px-4 py-3">Subscription billing, checkout, and webhook processing</td>
                  <td class="px-4 py-3">USA</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="mt-4 text-sm text-base-content/60">
            ResellerIO will provide at least 30 days' prior written notice before adding or replacing any sub-processor. The Controller may object in writing within that period.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">6. International Transfers</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            All primary processing takes place in the United States. Where ResellerIO transfers Personal Data to sub-processors, it ensures that appropriate safeguards are in place, including Standard Contractual Clauses (SCCs) or other mechanisms approved under applicable data protection law.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">7. Security Measures</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            ResellerIO implements the following technical and organisational measures:
          </p>
          <ul class="mt-4 list-disc pl-6 space-y-2 text-base leading-7 text-base-content/80">
            <li>TLS encryption in transit for all data exchanges.</li>
            <li>
              Encryption at rest for stored objects where supported by the configured storage provider.
            </li>
            <li>
              Password hashing using PBKDF2-SHA256 before storage; API tokens hashed before storage.
            </li>
            <li>
              HttpOnly session cookies with SameSite protections and Secure cookies in production.
            </li>
            <li>HTTPS enforcement and HSTS in production deployments.</li>
            <li>Origin allowlists for browser-based API access.</li>
            <li>
              Signed object-storage upload/download workflows and HMAC-verified billing webhooks.
            </li>
            <li>Rate limiting for public storefront inquiries and archive validation for imports.</li>
            <li>Least-privilege access controls and role-based separation for infrastructure.</li>
            <li>
              Operational logging and monitoring for service health, abuse prevention, and incident response.
            </li>
          </ul>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">
            8. Data Subject Rights Assistance
          </h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            ResellerIO will, upon request, assist the Controller in fulfilling its obligations to respond to Data Subject rights requests (access, rectification, erasure, restriction, portability, and objection) taking into account the nature of the processing and the information available to ResellerIO.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">9. Data Breach Notification</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            In the event of a confirmed Personal Data breach, ResellerIO will notify the Controller within 72 hours of becoming aware of the breach, providing sufficient information to allow the Controller to meet its own notification obligations.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">10. Term and Termination</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            This DPA remains in effect for the duration of the Service agreement. Upon termination, ResellerIO will delete or return all Personal Data within 30 days unless applicable law requires longer retention. Obligations of confidentiality and security survive termination.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">11. Governing Law</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            This DPA is governed by the laws of the State of Texas, United States, without regard to its conflict of law provisions, unless a mandatory provision of applicable data protection law requires otherwise.
          </p>

          <h2 class="mt-10 text-2xl font-semibold tracking-tight">12. Contact</h2>
          <p class="mt-4 text-base leading-7 text-base-content/80">
            Data protection enquiries:
            <a href="mailto:privacy@resellerio.com" class="text-primary underline">
              privacy@resellerio.com
            </a>
          </p>

          <div class="mt-12 flex gap-4">
            <.link navigate={~p"/"} class="btn btn-ghost rounded-full">← Back to home</.link>
            <.link navigate={~p"/privacy"} class="btn btn-outline rounded-full">Privacy Policy</.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
