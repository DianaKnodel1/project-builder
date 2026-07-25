import type { ReactNode } from "react";
import { ShieldCheck, Lock, CheckCircle2, FileText, Calendar } from "lucide-react";
import { useTenant } from "@/contexts/TenantContext";
import { usePortalTheme } from "@/hooks/use-portal-theme";

/**
 * Gemeinsamer Rahmen für die Auth-Seiten des Portals.
 * Das Layout richtet sich nach dem gewählten Portal-Design des Tenants.
 * Die Formulare selbst bleiben unverändert und kommen als children herein.
 */
export default function PortalAuthShell({
  title,
  description,
  children,
  footer,
  width = "md",
}: {
  title: string;
  description?: string;
  children: ReactNode;
  footer?: ReactNode;
  width?: "md" | "lg";
}) {
  const { tenant } = useTenant();
  const theme = usePortalTheme();
  const t = theme.tokens;
  const name = tenant?.name ?? "Mitarbeiter-Portal";
  const maxW = width === "lg" ? "max-w-lg" : "max-w-md";
  const darkBrand = theme.id === "classic";

  const brandMark = (
    <div className="flex items-center gap-3">
      {tenant?.logo_url ? (
        <img src={tenant.logo_url} alt={name} className="h-9 w-auto" />
      ) : (
        <div className={`h-9 w-9 rounded-lg flex items-center justify-center ${darkBrand ? "bg-slate-900/10" : "bg-primary/10"}`}>
          <ShieldCheck className={`h-5 w-5 ${darkBrand ? "text-slate-700" : "text-primary"}`} />
        </div>
      )}
      <span
        className={`font-heading font-semibold text-base tracking-tight ${darkBrand ? "text-slate-700" : "text-foreground"}`}
      >
        {name}
      </span>
    </div>
  );

  const features = [
    { icon: FileText, text: "Aufträge & Dokumente zentral verwalten" },
    { icon: Calendar, text: "Termine im Blick behalten" },
    { icon: ShieldCheck, text: "DSGVO-orientiert & verschlüsselt" },
  ];

  const trustRow = (
    <div className={`mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 ${t.mutedText}`}>
      <span className="flex items-center gap-1.5">
        <Lock className="h-3.5 w-3.5" /> Sicherer Login
      </span>
      <span className={`h-1 w-1 rounded-full ${darkBrand ? "bg-white/20" : "bg-border"}`} />
      <span className="flex items-center gap-1.5">
        <ShieldCheck className="h-3.5 w-3.5" /> DSGVO-orientiert
      </span>
      <span className={`h-1 w-1 rounded-full ${darkBrand ? "bg-white/20" : "bg-border"}`} />
      <span className="flex items-center gap-1.5">
        <CheckCircle2 className="h-3.5 w-3.5" /> 100% online
      </span>
    </div>
  );

  const formBlock = (
    <div className={`w-full ${maxW} relative`}>
      {/* Marke (mobil bzw. wenn kein Seitenpanel) */}
      <div className={`${t.brandPanel ? "lg:hidden " : ""}flex justify-center mb-8`}>{brandMark}</div>

      <div className={t.card}>
        <div className={t.cardPadding}>
          <div className="space-y-2">
            <h1 className={t.heading}>{title}</h1>
            {description && <p className={t.subText}>{description}</p>}
          </div>
          {children}
        </div>
      </div>

      {footer}
      {trustRow}
    </div>
  );

  return (
    <div className={t.page}>
      {t.decor === "waves" && (
        <div className="hidden lg:block absolute inset-y-0 left-0 w-1/2 pointer-events-none">
          <div className="absolute inset-0 bg-gradient-to-br from-slate-200/95 via-slate-300/90 to-slate-400/85" />
          <svg className="absolute inset-0 w-full h-full" viewBox="0 0 800 1000" preserveAspectRatio="xMidYMid slice" fill="none">
            <path d="M0,400 Q200,300 400,450 T800,400 L800,1000 L0,1000 Z" fill="url(#wave1)" opacity="0.35" />
            <path d="M0,500 Q300,400 500,550 T800,500 L800,1000 L0,1000 Z" fill="url(#wave2)" opacity="0.25" />
            <defs>
              <linearGradient id="wave1" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#e2e8f0" />
                <stop offset="100%" stopColor="#94a3b8" />
              </linearGradient>
              <linearGradient id="wave2" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#cbd5e1" />
                <stop offset="100%" stopColor="#64748b" />
              </linearGradient>
            </defs>
          </svg>
        </div>
      )}

      {t.decor === "glow" && (
        <>
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_25%_15%,hsl(var(--primary)/0.10),transparent_55%)] pointer-events-none" />
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_80%_85%,hsl(var(--primary)/0.06),transparent_55%)] pointer-events-none" />
        </>
      )}

      {t.brandPanel ? (
        <>
          <aside
            className={`hidden lg:flex lg:w-1/2 relative z-10 flex-col justify-between p-12 xl:p-16 ${
              darkBrand ? "text-slate-900" : "bg-muted/40 border-r border-border text-foreground"
            }`}
          >
            {brandMark}

            <div className="space-y-8 max-w-md">
              <div className="space-y-4">
                <h2
                  className={`text-4xl xl:text-5xl font-heading font-bold leading-tight tracking-tight ${
                    darkBrand ? "text-slate-900" : "text-foreground"
                  }`}
                >
                  Dein sicherer Zugang zum Arbeitsbereich.
                </h2>
                <p className={`text-base xl:text-lg leading-relaxed ${darkBrand ? "text-slate-600" : "text-muted-foreground"}`}>
                  Aufträge, Termine und Dokumente — übersichtlich an einem Ort. Schnell, sicher und jederzeit verfügbar.
                </p>
              </div>

              <ul className="space-y-3">
                {features.map(({ icon: Icon, text }) => (
                  <li key={text} className={`flex items-center gap-3 text-sm ${darkBrand ? "text-slate-700" : "text-muted-foreground"}`}>
                    <span
                      className={`h-8 w-8 rounded-lg flex items-center justify-center shrink-0 ${
                        darkBrand ? "bg-white/70 shadow-sm" : "bg-card border border-border"
                      }`}
                    >
                      <Icon className={`h-4 w-4 ${darkBrand ? "text-slate-700" : "text-primary"}`} />
                    </span>
                    {text}
                  </li>
                ))}
              </ul>
            </div>

            <div className={`flex items-center gap-2 text-xs ${darkBrand ? "text-slate-500" : "text-muted-foreground"}`}>
              <Lock className="h-3.5 w-3.5" />
              <span>Verschlüsselte Verbindung · SSL/TLS</span>
            </div>
          </aside>

          <main className="flex-1 flex items-center justify-center p-6 sm:p-10 relative z-10">{formBlock}</main>
        </>
      ) : (
        <main className="w-full flex items-center justify-center relative z-10">{formBlock}</main>
      )}
    </div>
  );
}
