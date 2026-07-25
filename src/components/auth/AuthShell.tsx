import type { ReactNode } from "react";
import { ShieldCheck, Lock, CheckCircle2 } from "lucide-react";
import { useTenant } from "@/contexts/TenantContext";

/**
 * Einheitlicher, schlichter Rahmen für alle Auth-Seiten
 * (Login, Registrierung, Passwort vergessen).
 * Ruhige Karte auf neutralem Hintergrund – keine Gradients, keine Effekte.
 */
export default function AuthShell({
  title,
  description,
  children,
  width = "md",
}: {
  title: string;
  description?: string;
  children: ReactNode;
  width?: "md" | "lg";
}) {
  const { tenant } = useTenant();
  const name = tenant?.name ?? "Mitarbeiter-Portal";

  return (
    <div className="min-h-screen bg-muted/40 flex flex-col items-center justify-center px-4 py-10">
      <div className={`w-full ${width === "lg" ? "max-w-lg" : "max-w-md"}`}>
        {/* Marke */}
        <div className="flex flex-col items-center gap-3 mb-8">
          {tenant?.logo_url ? (
            <img src={tenant.logo_url} alt={name} className="h-10 w-auto" />
          ) : (
            <div className="h-11 w-11 rounded-xl bg-primary/10 flex items-center justify-center">
              <ShieldCheck className="h-5 w-5 text-primary" />
            </div>
          )}
          <span className="font-heading font-semibold text-base text-foreground tracking-tight">
            {name}
          </span>
        </div>

        {/* Karte */}
        <div className="rounded-2xl border border-border bg-card shadow-sm">
          <div className="p-7 sm:p-8 space-y-6">
            <div className="space-y-1.5">
              <h1 className="text-xl font-heading font-semibold text-foreground">{title}</h1>
              {description && (
                <p className="text-sm text-muted-foreground leading-relaxed">{description}</p>
              )}
            </div>
            {children}
          </div>
        </div>

        {/* Trust-Zeile */}
        <div className="mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-xs text-muted-foreground">
          <span className="flex items-center gap-1.5">
            <Lock className="h-3.5 w-3.5" /> Sicherer Login
          </span>
          <span className="h-1 w-1 rounded-full bg-border" />
          <span className="flex items-center gap-1.5">
            <ShieldCheck className="h-3.5 w-3.5" /> DSGVO-orientiert
          </span>
          <span className="h-1 w-1 rounded-full bg-border" />
          <span className="flex items-center gap-1.5">
            <CheckCircle2 className="h-3.5 w-3.5" /> SSL-verschlüsselt
          </span>
        </div>
      </div>
    </div>
  );
}
